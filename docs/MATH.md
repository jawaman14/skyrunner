# The Mathematics of Skyrunner

*An essay for a mathematician, with the source files named so each claim can be checked.*

## Prologue: a game is a family of stochastic processes

Skyrunner is a game about smuggling and policing in the early 1980s, but a mathematician will see something else in it: a
deterministic rigid-body integrator coupled to a collection of independent pseudo-random streams, a detection model built from
the radar range equation, mean-reverting price processes, a Bernoulli hazard on every truck, a zero-sum matrix game solved by
fictitious play, and a casino whose edges can be computed by hand. Almost none of this is exotic. What is unusual is that it all
runs together, deterministically, from one integer seed, and that the game's *balance* is a statistical estimation problem
solved by Monte Carlo.

This essay walks through those pieces in the order in which the machine meets them: first the randomness and why it can be
trusted, then the physics, then what can be seen, then what things cost, then what can go wrong on the road, then the game
between the two sides, and last the one place where the mathematics is simple enough to finish. Where a number is derived, I
derive it; where it is merely *chosen* to make the game feel right, I say so (Section 8), because a reader who cannot tell the
two apart will be misled about what the model claims.

Notation: $\mathcal U(a,b)$ is the uniform law, $\mathcal N(\mu,\sigma^2)$ the normal law, $\mathbf 1_A$ an indicator. Constants are
quoted from the source with their names in `code font`.

---

## 1. Randomness: one Mersenne Twister, many streams

Every random draw in the simulation comes from `PyRandom` (`scripts/util/py_random.gd`), a bit-exact port of CPython's
`random.Random`: the Mersenne Twister MT19937 of Matsumoto and Nishimura, period $2^{19937}-1$, seeded the way CPython seeds it
(`init_by_array` on the 32-bit words of $|n|$). Two derived generators matter.

**Uniform floats.** Two 32-bit outputs $a, b$ are combined as
$$U=\frac{(a\gg 5)\cdot 2^{26}+(b\gg 6)}{2^{53}},$$
a uniform on the dyadic grid of mesh $2^{-53}$, so $U\in[0,1)$ and every double in the grid is equally likely.

**Normal draws.** `gauss` is CPython's Box–Muller with a cached second variate: with $u_1,u_2$ uniform,
$$Z_1=\cos(2\pi u_1)\sqrt{-2\ln(1-u_2)},\qquad Z_2=\sin(2\pi u_1)\sqrt{-2\ln(1-u_2)},$$
and $Z_2$ is returned on the next call. (The `1-u_2` keeps the logarithm's argument in $(0,1]$.)

Why bit-exactness? The game began as a Python prototype and was ported. A port is only checkable if it reproduces the original
*sample paths*, not merely the distributions: for a given seed, the Godot season must end the same night, for the same reason, as
the Python one. The frozen fixtures in `tests/fixtures` are those paths.

**Streams.** A single stream would couple everything: adding one draw to the casino would shift every later draw in the economy.
So each subsystem owns a generator seeded with the session seed plus a constant: the stash network $+41$, the Family $+97$,
the police $+99$, the court $+107$, the market $+113$, the analyst $+909$, the casino $+939$, the casino's tables $+941$, the
dealership's checkpoint roll $+947$, and so on (table in `docs/DESIGN.md`). Distinct seeds put the generators at unrelated points
of the twister's state space, so the streams behave as independent for every purpose here, although independence is, strictly, a
heuristic: no proof exists that two MT19937 sequences seeded by `init_by_array` of nearby integers are independent, only that
collisions are astronomically unlikely and that no test the game has ever applied has found one. The rule "a new system draws
from a new stream" is what keeps old replays valid, and `tests/test_switches.gd` enforces it by scanning the simulation for any
draw from a global generator or any read of the wall clock.

A consequence worth stating: the simulation is a deterministic function
$$\Phi:(\text{seed},\ \text{command sequence},\ \Delta t\text{-sequence})\longmapsto \text{state}.$$
A save file, a network snapshot and a balance run are all evaluations of $\Phi$. The only nondeterminism in the program is the
human's hand.

---

## 2. The flight model: a rigid body in a standard atmosphere

The aircraft is a six-degree-of-freedom rigid body (`scripts/sim/flight/flight_dynamics.gd`). Its *data*, aerodynamic tables,
inertia, gear and engine curves, are read from JSBSim-format XML; the *integrator* is the game's own.

### 2.1 Equations of motion

In body axes ($x$ forward, $y$ right, $z$ down), with $\mathbf v$ the body-axis velocity, $\boldsymbol\omega=(p,q,r)$ the body
rates, $m$ the mass and $I$ the inertia tensor, the Newton–Euler equations are
$$\dot{\mathbf v}=\frac{\mathbf F}{m}-\boldsymbol\omega\times\mathbf v,\qquad
\dot{\boldsymbol\omega}=I^{-1}\bigl(\mathbf M-\boldsymbol\omega\times I\boldsymbol\omega\bigr),$$
where $\mathbf F$ and $\mathbf M$ sum aerodynamics, propulsion, undercarriage and weight. Attitude is a unit quaternion $\mathbf q$
(body to local north–east–down), advanced by
$$\dot{\mathbf q}=\tfrac12\,\mathbf q\otimes(\boldsymbol\omega,0),$$
and renormalised each step. The scheme is *semi-implicit* (symplectic) Euler at $\Delta t=1/120$ s: update $\mathbf v$ and
$\boldsymbol\omega$ first, then advance $\mathbf q$ and the position with the new values. For a conservative system this keeps the
energy error bounded rather than drifting; for this one, with stiff gear springs and friction, it is chosen mainly for stability.
The step is small enough that the fastest mode of the airframe (short-period pitch, a few hertz) is resolved by dozens of steps.

### 2.2 The atmosphere

Density, pressure and sound speed come from the International Standard Atmosphere in the troposphere (altitude $h$ in feet,
clamped to $[-2000, 36089]$):
$$T=518.67-0.00356616\,h\ \ [^\circ\mathrm R],\qquad
P=2116.22\Bigl(\frac{T}{518.67}\Bigr)^{5.2559}\ \mathrm{psf},\qquad
\rho=\frac{P}{R_{\!air}T},\qquad a=\sqrt{\gamma R_{\!air}T}.$$
The exponent $5.2559=g/(LR)$ is the hydrostatic exponent for a linear lapse rate $L$. Dynamic pressure is
$\bar q=\tfrac12\rho V_T^2$, and the cockpit's calibrated-style airspeed is the equivalent airspeed
$V_{\!c}=V_T\sqrt{\rho/\rho_0}$, exactly the scaling that makes lift at a given $V_c$ independent of altitude.

### 2.3 Aerodynamics, propulsion, gear

Forces are looked up, not derived: the lift, drag and side-force coefficients are the XML's tabulated functions of angle of
attack $\alpha$, sideslip $\beta$, control deflections and so on, evaluated by a small expression interpreter (`fdm_func.gd`) and
rotated from wind to body axes by the usual
$$\mathbf F_{\!body}=\begin{pmatrix}\cos\alpha\cos\beta&-\cos\alpha\sin\beta&-\sin\alpha\\ \sin\beta&\cos\beta&0\\
\sin\alpha\cos\beta&-\sin\alpha\sin\beta&\cos\alpha\end{pmatrix}\mathbf F_{\!wind}.$$
A propeller turns shaft power into thrust through the propeller's own tables:
$$T=C_T(J)\,\rho\,n^2d^4,\qquad P=C_P(J)\,\rho\,n^3d^5,$$
with $J=V/(nd)$ the advance ratio, $n$ the rotation rate and $d$ the diameter; the rotation rate itself comes from a torque
balance, with a governor for constant-speed propellers.

The undercarriage is a set of contact points, each a one-sided spring–damper:
$$N=\max\bigl(0,\ k\delta+c\dot\delta\bigr),$$
where $\delta$ is the penetration below the ground plane. Friction is *regularised Coulomb*: the tyre's rolling and side forces
are $-\mu N\,\mathrm{sat}(v/\varepsilon)$ with $\mathrm{sat}$ the clamp to $[-1,1]$ and $\varepsilon\approx0.5$–$0.6$ ft/s, which
replaces the discontinuous sign function with a steep linear ramp so that a parked aeroplane actually stays parked instead of
chattering about zero velocity.

### 2.4 Turbulence as an Ornstein–Uhlenbeck gust

Gusts are a Gauss–Markov process in the air mass, an Ornstein–Uhlenbeck process with correlation time $\tau=1.5$ s and
stationary standard deviation $\sigma\in\{3,7,15\}$ ft/s for light, moderate and severe turbulence:
$$g_{n+1}=\Bigl(1-\frac{\Delta t}{\tau}\Bigr)g_n+\sigma\sqrt{\frac{2\Delta t}{\tau}}\,\xi_n,\qquad \xi_n\sim\mathcal N(0,1).$$
With $a=\Delta t/\tau$, the stationary variance of this recursion is $\sigma^2\dfrac{2a}{1-(1-a)^2}=\sigma^2\dfrac{1}{1-a/2}$;
at $\Delta t=1/120$ s the relative bias in variance is $a/2\approx0.28\%$, which nobody will ever feel. (The vertical component is
scaled by $0.6$.) The gust has its own random stream, so turbulence never perturbs the economy.

---

## 3. Seeing and being seen: a detection model

Nobody on the law side sees the truth; they see tracks. `SensorNet` (`scripts/sim/sensors.gd`) turns a target's *signature* into
a noisy, aging track, and the same geometry drives the runner's radar detector.

### 3.1 The radar horizon

Radar waves bend slightly toward the ground; the standard fix is to keep straight rays and enlarge the Earth by $k=4/3$. A target
at ground range $d$ then sits lower than the beam's straight line by
$$\Delta h(d)=\frac{d^2}{2kR_\oplus},\qquad R_\oplus=6371\ \text{km}.$$
At $d=50$ km this is $147$ m; at $100$ km it is $589$ m. Turn the relation around: an aircraft flying at height $h$ above a
radar's local horizon is invisible beyond $d_{\max}=\sqrt{2kR_\oplus h}$. At $h=100$ m that is $41$ km. This is why the game's
"fly low" advice works, and why a hill between you and a site is worth more than a good transponder.

### 3.2 Probability of detection

Within the horizon the detection probability falls off as a steep Hill function of range:
$$P_d(d)=\frac{1}{1+(d/r_{50})^{8}},\qquad r_{50}=0.9\,R_{\text{site}}\,\sigma^{1/4},$$
where $R_{\text{site}}$ is the site's rated reach and $\sigma$ the aircraft's relative radar cross-section. The fourth root is the
radar range equation, $R_{\max}\propto\sigma^{1/4}$, so a Twin Otter ($\sigma=2.2$, factor $1.218$) is seen about 29% farther than a
Cherokee ($\sigma=0.8$, factor $0.946$). The exponent 8 makes the transition sharp but not a cliff: $P_d=0.5$ at $d=r_{50}$,
$0.86$ at $0.8\,r_{50}$, $0.19$ at $1.2\,r_{50}$. A track is declared when $P_d>0.02$.

Two further effects are deterministic filters on top of $P_d$. A moving-target indicator cancels returns whose radial speed
$|\mathbf v\cdot\hat{\mathbf r}|$ is below $18$ m/s (about 35 kt) beyond 600 m, which is the notch a pilot exploits by flying
*across* the beam. And each site only looks once per scan period (4.8 s for ground radars, 12 s for the aerostat), so between
looks the last observation stands: a sampled-data measurement, with a track timeout of 45 s.

### 3.3 The season-level shadow of the same idea

The strategic game (Section 6) cannot afford a radar simulation per night, so it replaces all of the above by a calibrated
probability. A night's flight in zone $z$ is detected with
$$p=\min\bigl(0.97,\ v\cdot(c_z+c^{\,\text{aerostat}}_z+0.30\,\mathbf 1_{\text{tip}}+\pi_z)+0.25\,\mathbf 1_{\text{decoy}}\bigr),$$
where $c_z$ is a zone constant measured from real flights by the `Tactical` simulator, $\pi_z$ is the *analysts' pattern*
(the law side's estimate of where you will be, built from the last four nights' sightings), and $v$ is a visibility factor that
combines sky and moon. This is a reduced model in the technical sense: the fine model (radar, flight, police AI) is run many times
to estimate the coarse model's parameters, then the coarse model is used where the fine one is too slow.

---

## 4. Prices: mean reversion and an elasticity law

### 4.1 An Ornstein–Uhlenbeck price index

For each good $g$ in each market $m$ the economy keeps an index $X_{g,m}$ with long-run level 1, which moves as
$$X\leftarrow 1+(X-1)\,e^{-\Delta/\tau}+\mathcal N\!\bigl(0,\ v_g^2\,\Delta/60\bigr),\qquad \tau=1800\ \text{s},\ \Delta=10\ \text{s}.$$
This is the exact transition of the Ornstein–Uhlenbeck diffusion $dX=-\theta(X-1)\,dt+s\,dW$ for the mean part, with
$\theta=1/\tau$, and an Euler-sized noise term. Taking the continuous process, the stationary variance is $s^2/2\theta$; with
$s^2=v_g^2/60$ per second this is $15\,v_g^2$, a stationary standard deviation of $\sqrt{15}\,v_g\approx3.9\,v_g$ (the discrete
recursion gives $v_g^2\Delta/60/(1-e^{-2\Delta/\tau})$, within half a percent). Cocaine, with $v=0.05$, therefore wanders with
standard deviation $0.19$ about its mean; general freight, $v=0.012$, with $0.046$. The volatilities are the *only* statistics of
the walk; everything else is a multiplicative premium laid on top (police nearby, a rival's undercutting, scarcity after a seizure,
a glut after one's own delivery, a storm, a news event), each with its own exponential decay ($600$ s for busts, $900$ s for
gluts, $1200$ s for scarcity).

### 4.2 Supply, demand and an elasticity

For the hot goods the street price is not a pure walk but a function of two relaxing state variables, supply $S$ and demand $D$
(both 1 at rest):
$$\frac{P}{P_0}\ \propto\ \Bigl(\frac{D}{S}\Bigr)^{\epsilon},\qquad \epsilon=0.55,$$
a constant-elasticity law: a 10% shortfall in supply raises the price by about $5.5\%$. $S$ relaxes toward its target with time
constant $900$ s, $D$ toward 1 with $2400$ s, and *disruption* to the distribution network (arrests, raids, rival shipments)
pushes the supply target down to $1-0.6\,\delta$ of the source, with $\delta\in[0,1]$. That is a coupled linear system with two
different time constants driven by event impulses: the price after a big raid dips, overshoots as demand lags, and decays on the
slower clock. It is the only part of the economy where the model has an *economic* interpretation rather than a statistical one.

---

## 5. The road: a hazard on every truck

Stash product moves by truck (`scripts/sim/stashes.gd`, `logistics.gd`). Each run is a Bernoulli trial with probability
$$p=\operatorname{clamp}\Bigl(\bigl(0.04+\tfrac{h}{300}+r\bigr)\,\mu,\ 0,\ 0.85\Bigr),$$
where $h$ is the stash's accumulated heat, $r$ is a risk increment (a tipped runner, a police strip), and $\mu\le1$ is a cover
multiplier from the organisation's fleet. If the trial succeeds, the roadblock sits at a fraction $U\sim\mathcal U(0.2,0.9)$ of the
route. A truck with *steel* $a$ drives through it with probability $a$. The probability that a given run is lost to the
roadblock is therefore
$$\Pr[\text{seized}]=p\,(1-a).$$
At $h=30$ (a warm stash), $r=0$, no fleet: $p=0.04+0.10=0.14$. An ambulance conversion ($\mu=0.55$) gives $0.077$; add an
armoured truck ($a=0.6$) and the figure falls to $0.077\times0.4=0.031$. Checkpoints and patrols on the ground (the street
war) add a second, spatial hazard: a truck within $120$ m of a police checkpoint is stopped outright, and one passing a
roving patrol is stopped with probability $0.25$ ($0.5$ if the stash it is heading for is already known). The fleet's cover $c$ and
steel $a$ get a stopped truck past with probability $\min(0.9,\,c+a)$, rolled once for each (truck, stop) pair, which is why the
result is cached by pair rather than redrawn on every tick (a truck sitting at a checkpoint must get one answer, not many chances).

A second, smaller piece of arithmetic: a truck burns $0.35$ gal/km from a $25$-gal tank, so with a 3-gal reserve its usable range
is $(25-3)/0.35\approx63$ km; a run longer than that pays a fill-up of $240$ s plus $6$ s per gallon. Run time itself is
$45\ \text{s}+1.3\,d/v$, the factor $1.3$ being the average detour of a road over the crow's line, and $v$ the fleet's best speed,
$11$ m/s unmodified, $15$ m/s in the fastest van, so a 3-km run takes $400$ s or $305$ s. Fuel, risk and time are all linear
in distance, so the choice of vehicle reduces to comparing three slopes.

---

## 6. The season: a zero-sum matrix game, solved by fictitious play

### 6.1 The game

The headquarters mode plays a *season* of nights between two sides. Each side has a finite set of **policies** (scripted
strategies of the bots in `scripts/bots/`): $m$ for the runner, $n$ for the task force. Fix a policy pair $(i,j)$ and a seed $s$;
the season is a deterministic function of $(i,j,s)$, and its result is $W_{ij}(s)\in\{0,1\}$, runner wins or not. The payoff
matrix is the win probability
$$A_{ij}=\mathbb E_s[W_{ij}(s)],$$
estimated by $\hat A_{ij}$, the fraction of wins over $N$ seasons. The game is *constant-sum* (what one side wins the other loses),
so by von Neumann's minimax theorem
$$v=\max_{p\in\Delta_m}\ \min_{q\in\Delta_n}\ p^{\!\top}Aq=\min_{q}\max_{p}\ p^{\!\top}Aq$$
exists, and $v$ is the *fair win rate*: the runner's win probability when both sides play optimally over the bots' repertoire.
The design target is $v\in[0.45,0.55]$.

### 6.2 Solving it

`Strategic.equilibrium` uses **fictitious play** (Brown 1951; Robinson 1951 proved convergence for zero-sum games): each side in
turn plays a best response to the *empirical mixture* of the other side's past plays, and the empirical frequencies converge to
an optimal mixed strategy. After $T=20{,}000$ rounds the empirical mixtures $(\bar p,\bar q)$ bracket the value,
$$\min_j\ \bar p^{\!\top}A_{\cdot j}\ \le\ v\ \le\ \max_i\ A_{i\cdot}\bar q,$$
and the gap between the two sides of that inequality is an exact certificate that the solution is good. The code returns the
bilinear value $\bar p^{\!\top}A\bar q$, which lies inside that bracket. (Robinson's rate is slow in general,
$O(T^{-1/(m+n-2)})$, but for matrices of this size it is ample; a linear program would give the exact value, and fictitious play
is used because it is short and needs no solver.)

Two diagnostics come out of the same matrix. A **dominant** strategy (one that beats or ties every column) is a design bug: it
would mean the choice is not a choice. And an **ablation**: switch a mechanic off (the bribe, the wiretap, the decoys...), recompute
$v$, and read the change as the mechanic's worth in percentage points.

### 6.3 The estimation problem

$A$ is unknown and each $\hat A_{ij}$ is a binomial proportion with
$$\operatorname{sd}(\hat A_{ij})=\sqrt{\frac{A_{ij}(1-A_{ij})}{N}}\ \le\ \frac{1}{2\sqrt N}.$$
At $N=200$ seasons a cell is only known to about $\pm3.5$ points (one standard deviation); at $N=1000$, $\pm1.6$; at $N=2000$,
$\pm1.1$. With 40 policy pairs that is $80{,}000$ seasons at $N=2000$, a minute or two on ten cores.

There is a subtler point that matters to a mathematician: $v(\hat A)$ is a **biased** estimator of $v(A)$. The value is a
max-min of a noisy matrix, and a max of noisy numbers is biased upward while a min is biased downward; for the *runner's*
maximisation the bias favours the runner, and the size of it depends on how many near-ties the matrix has. This is one reason a
200-per-cell run read $54.6\,\%$ for a configuration that, at 1000 per cell, read $58.3\,\%$: part of the shift is simply the
sampling error of a max-min of forty noisy cells, and the lesson recorded in `docs/BALANCE.md` is to take $N\ge1000$ per cell
before trusting a figure.

### 6.4 Tuning by root-finding on a noisy monotone function

The balance parameter is the prize the runner earns per run, `run_payout`. The equilibrium win rate is monotone in it and nearly
linear over the range tried:

| `run_payout` | 12000 | 11500 | 11000 | 10750 | 10500 | 10000 |
|---|---|---|---|---|---|---|
| runner wins at equilibrium | 58.3 % | 55.0 % | 53.1 % | 51.7 % | 49.5 % | 46.1 % |

The slope is about $6.1$ percentage points per \$1000 (the chord from \$10000 to \$12000 gives $(58.3-46.1)/2000$); linear
interpolation puts the $50\,\%$ crossing near $\$10{,}640$. The adopted value, \$10{,}750, sits at $51.7\,\%$ and was confirmed at
$N=2000$ per cell ($51.6\,\%$): this is root-finding on a function we can only evaluate with noise, so one stops when the
bracket is inside the target band and the confirmation run agrees, rather than chasing the exact root, which the noise could not
resolve anyway.

---

## 7. The casino: where the mathematics finishes

The Hotel Cielo (`scripts/sim/casino_games.gd`) is the one subsystem where every expectation can be computed on paper, and the
tests check each edge numerically. Let the *house edge* be $e=-\mathbb E[\text{player's net}]/\text{stake}$.

**Roulette** (one zero, 37 pockets). A straight-up bet pays 35 to 1: $\mathbb E=\tfrac1{37}\cdot35-\tfrac{36}{37}=-\tfrac1{37}$. Every
other bet covering $k$ numbers pays $36/k-1$ to 1 and has the same expectation, so $e=1/37=2.703\,\%$ for all bets.

**Craps.** On the pass line the shooter wins on 7 or 11 at once (probability $8/36$), loses on 2, 3, 12 ($4/36$), and otherwise
the point $t\in\{4,5,6,8,9,10\}$ is established and must be repeated before a 7. With $a_t$ the number of ways to roll $t$, the
probability of making the point is $a_t/(a_t+6)$, and summing gives
$$\Pr[\text{pass wins}]=\frac{8}{36}+2\Bigl(\tfrac{3}{36}\cdot\tfrac{3}{9}+\tfrac4{36}\cdot\tfrac4{10}+\tfrac5{36}\cdot\tfrac5{11}\Bigr)=\frac{244}{495},$$
so $e_{\text{pass}}=1-2\cdot\frac{244}{495}=\frac{7}{495}=1.414\,\%$. The don't-pass bet, which bars the 12, has
$e=3/220=1.364\,\%$. *Free odds* are paid at the true odds (6 to 5 on the 6 and 8, 3 to 2 on the 5 and 9, 2 to 1 on the 4 and
10) and carry no edge at all, so they dilute the edge on the *total* amount at risk: the more odds a player takes behind a
line bet, the closer the average edge on the whole wager comes to zero.

**Baccarat** (punto banco, eight decks, the full third-card tableau). The outcome probabilities of a coup are about
$0.4586$ banker, $0.4462$ player, $0.0952$ tie. At even money the player bet has $e=0.4586-0.4462=1.24\,\%$; the banker bet pays
0.95 (a 5% commission), so $e=0.4462-0.95\times0.4586=1.06\,\%$; the tie, paying 8 to 1, has
$e=1-9\times0.0952\approx14.4\,\%$, the reason no sensible player touches it.

**Blackjack** (two decks, dealer stands on all 17s, 3 to 2 on a natural, double on any two cards, no splitting). There is no
closed form; the edge, about $0.7$–$1\,\%$ under basic strategy, is a Monte Carlo estimate, and the table's advice line is the
basic-strategy decision table.

**Slots.** Three reels of twenty stops each ($20^3=8000$ equally likely outcomes); the return to player is
$$\mathrm{RTP}=\frac{1}{8000}\sum_{(a,b,c)}\text{pay}(a,b,c)=91.87\,\%$$
by exhaustive enumeration, an edge of $8.13\,\%$.

### 7.1 The owner's side

A stake is a fraction $\theta\in\{0.1,\dots,0.4\}$ of the house. The house grosses about $G=\$16{,}000$ an hour (modulated by tourism
and the rival), the General skims a fraction $s\in[0.06,0.14]$ (more when he likes you less) and the Family takes $0.12$, so the
owner's income rate is
$$\dot W=\theta\,G\,(1-s-0.12).$$
A tenth costs \$9,000; at $s=0.10$ the rate is $0.1\times16000\times0.78=\$1{,}248$ an hour, a payback of about $7.2$ hours
(between $6.9$ at the best skim and $7.6$ at the worst). The cage washes street cash for a fee $f=0.08+s\in[0.14,0.22]$, with a
cap of \$8,000 an hour: laundering $n$ dollars returns $(1-f)n$ and costs the runner's case $1.5$ points of suspicion per
\$1000, at the price of $0.8$ points of the *casino's* own heat per \$1000.

---

## 8. What is derived and what is calibrated

It would be dishonest to leave the impression that everything above is first-principles. The honest classification:

* **Derived or standard**: the integrator, the atmosphere, the radar horizon and $\sigma^{1/4}$ scaling, the OU recursions, the
  casino edges, the minimax value and fictitious play. A reader can check these against a textbook.
* **Calibrated to the real game**: the zone detection constants $c_z$ in the season model (measured from simulated flights by
  `Tactical`); the ground war's `RANGE_SCALE=4` (every weapon's effective range is multiplied by 4 because squad fights start 250 m
  apart and at $1\times$ the simulated war came out 7% richer for the organisation than the flat model, a number chosen by
  comparing two simulators, not by physics); the price volatilities $v_g$.
* **Chosen for feel**: the hazard base rate $0.04$, the $1/300$ heat coefficient, the casino's $G$, every price in the dealership.
  These are tuned so the *equilibrium* lands in the design band, not so a unit analysis comes out clean, and `docs/BALANCE.md`
  records each change with the sample size that justified it.

The distinction matters when you want to change something. Altering the integrator's step changes the physics and needs a new
golden file; altering $G$ changes the story; altering the roadblock constant changes the equilibrium win rate by a measurable
amount that must be re-estimated at $N\ge1000$. Mathematically, the game is a modest system. What makes it interesting to build
is that it is a single deterministic function whose parameters can be tuned against a statistical objective, with the objective
itself computed by the game.

---

## Further reading in the repository

* `docs/DESIGN.md`: the systems, with the table of random streams.
* `docs/BALANCE.md`: every tuning decision, with its sample size and its measured effect.
* `tests/test_casino_games.gd`: the casino's edges, computed and checked.
* `scripts/balance/strategic.gd`: the season simulator and the equilibrium solver.
* `scripts/sim/flight/flight_dynamics.gd`: the integrator and the atmosphere.
