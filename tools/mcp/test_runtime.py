# /// script
# requires-python = ">=3.11"
# dependencies = ["mcp>=2.3,<3", "httpx>=0.27"]
# ///
"""Real job lifecycle and stdio checks. Run with uv run --script tools/mcp/test_runtime.py."""
import asyncio
import importlib.util
import os
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch
import run_tests as worker

from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client

SERVER = Path(__file__).with_name("skyrunner_mcp.py")
spec = importlib.util.spec_from_file_location("skyrunner_test_server", SERVER)
server = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = server
spec.loader.exec_module(server)


class Runtime(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        (server.ROOT / ".build").mkdir(exist_ok=True)
        self.temp = tempfile.TemporaryDirectory(dir=server.ROOT / ".build")
        self.work = patch.object(server, "WORK", Path(self.temp.name))
        self.work.start()
        server.JOBS.clear()

    async def asyncTearDown(self):
        for job in server.JOBS.values():
            if job.running:
                server._terminate_job(job, force=True)
                await job.proc.wait()
        self.work.stop()
        self.temp.cleanup()

    async def test_completed_job(self):
        output = "TEST FILE: test_fixture.gd — 1 passed, 0 failed\n1 passed, 0 failed in 0.1 s\n"
        command = "import sys; sys.stdout.buffer.write(%r)" % output.encode("utf-8")
        job = await server._start_job("fixture", [sys.executable, "-c", command],
                                      server._summarize_tests, timeout_s=10)
        await server._wait(job, 10)
        self.assertEqual(job.proc.returncode, 0)
        self.assertEqual(server._summarize_tests(job.text(), 0)["files with tests run"], 1)

    async def test_cancel_and_single_job_limit(self):
        job = await server._start_job("fixture", [sys.executable, "-c", "import time; time.sleep(60)"],
                                      server._summarize_plain, timeout_s=60)
        with self.assertRaises(server.ToolError):
            await server._start_job("second", [sys.executable, "-c", "pass"], server._summarize_plain)
        await server.skyrunner_job_cancel(job.id)
        self.assertFalse(job.running)

    async def test_deadline(self):
        job = await server._start_job("fixture", [sys.executable, "-c", "import time; time.sleep(60)"],
                                      server._summarize_plain, timeout_s=1)
        await server._wait(job, 15)
        self.assertFalse(job.running)
        self.assertIn("124", server._report(job))
        self.assertIn("FAILED", server._report(job))

    async def test_cancel_stops_descendant(self):
        marker = Path(self.temp.name) / "child-survived"
        child = "import time; from pathlib import Path; time.sleep(3); Path(%r).touch()" % str(marker)
        parent = "import subprocess,sys,time; subprocess.Popen([sys.executable,'-c',%r]); print('child-started',flush=True); time.sleep(60)" % child
        job = await server._start_job("tree", [sys.executable, "-u", "-c", parent],
                                      server._summarize_plain, timeout_s=60)
        for _ in range(100):
            if "child-started" in job.text():
                break
            await asyncio.sleep(0.05)
        self.assertIn("child-started", job.text())
        await server.skyrunner_job_cancel(job.id)
        await asyncio.sleep(4)
        self.assertFalse(marker.exists(), "cancellation must stop descendants too")

    async def test_stdio_initialization(self):
        params = StdioServerParameters(command=sys.executable, args=[str(SERVER)], env=dict(os.environ))
        async with stdio_client(params) as (reader, writer):
            async with ClientSession(reader, writer) as session:
                await session.initialize()
                listing = await session.list_tools()
                self.assertIn("skyrunner_run_tests", [t.name for t in listing.tools])
                result = await session.call_tool("skyrunner_list_tests", {"filter": "docs"})
                self.assertFalse(result.is_error)
                self.assertIn("test_docs.gd", result.content[0].text)


class TestWorker(unittest.TestCase):
    def test_failed_import_prevents_tests(self):
        for code, output in [(1, "import failed"), (0, "SCRIPT ERROR: broken"), (0, "Parse Error: broken")]:
            with self.subTest(code=code, output=output), patch.object(sys, "argv", ["worker", "godot", "--reimport"]):
                with patch.object(worker.subprocess, "run", return_value=worker.subprocess.CompletedProcess([], code, output)):
                    with patch.object(worker.subprocess, "call") as tests:
                        self.assertNotEqual(worker.main(), 0)
                        tests.assert_not_called()

    def test_successful_import_runs_literal_filter(self):
        with patch.object(sys, "argv", ["worker", "godot with spaces", "--reimport", "--filter", "docs"]):
            with patch.object(worker.subprocess, "run", return_value=worker.subprocess.CompletedProcess([], 0, "import OK")):
                with patch.object(worker.subprocess, "call", return_value=0) as tests:
                    self.assertEqual(worker.main(), 0)
                    tests.assert_called_once_with(["godot with spaces", "--headless", "--script", "res://tests/run_tests.gd", "--", "docs"])


if __name__ == "__main__":
    unittest.main()
