# Project 2: 1vs1 Reinforcement Learning

## The Role of Artificial Intelligence (Deep Q-Network)
This module introduces **Deep Reinforcement Learning (DRL)** to replace the decision-making core of the FSM. The unique feature of the implemented architecture is that the neural network (DQN - Deep Q-Network) acts at a *macro-tactical* level: it does not directly control the motor voltages but selects high-level logical actions (such as "Pursue ball", "Retreat", "Wait"). The underlying planner then translates this intention into continuous kinematic trajectories.

This hierarchical approach relieves the neural network from having to learn the complex non-holonomic stabilization equations of the robot from scratch, focusing learning entirely on tactical intelligence: positioning, spatial reading, and game control.

<div align="center">
  <img src="../assets/actor_critic_scheme.png" alt="RL Block Diagram"/>
  <br>
  <em>Block diagram of the RL architecture.</em>
</div>

## Training and Curriculum Learning
To avoid the *reward sparsity* phenomenon (where the agent never scores and learns nothing), training did not start in a complete scenario right away, but through an incremental **Curriculum Learning** process across 4 phases:
1. **Phase 0 (Basic Mechanics):** The agent learns to move and shoot against a stationary opponent.
2. **Phase 1 (Dynamic Obstacle):** The opponent moves randomly; the agent learns obstacle avoidance.
3. **Phase 2 (Clash with Tactical Intelligence):** The opponent is the complete FSM from Project 1. This is where actual tactics emerge via *Reward Shaping*.
4. **Phase 3 (Extreme Specialization):** Surgical fine-tuning of rewards to aggressively polarize the playing style.

## Reward Shaping and Playing Styles (Agents)
By modifying spatial metrics, temporal gradients, and penalties in the Reward function, the neural network was "shaped" to embody diametrically opposed tactical philosophies, resulting in several "specialist" agents:

- 🟢 **Continuo and Discreto (Balanced):** They combine offensive drive and defensive coverage (Continuo uses spatial gradients, Discreto uses zone thresholds). Continuo proves to be the strongest and most efficient in the long run.
- 🔴 **Striker and Zeman (Offensive):** Hyper-aggressive. They ignore defense to constantly pressure the ball. Zeman, in particular, was trained to use rebounds off the walls and maximize impact energy.
- 🔵 **Defender, Simeone, and Catenaccio Totale (Defensive):** They aim to protect their own goal obsessively. Simeone combines conservative coverage with lightning-fast and lethal counterattacks, proving to be one of the most stable networks overall.
- ⚪ **Standard:** Trained almost exclusively with terminal rewards (+10 goals, -15 conceded). It serves as a benchmark to demonstrate the absolute necessity of Reward Shaping to guide the neural network towards excellence in complex simulations.

## Performance and Results (RL vs FSM)
Championships demonstrate a clear dominance of the neural networks over the deterministic FSM. The RL agents (primarily Continuo) capitalize on the greater dynamism of their policy compared to the solid but sequential states of the FSM. 

The underlying simulator is the exact same one used in the 1vs1 project. If you wish to visually watch the RL play against the FSM (or even against another RL agent), you can do so, as the simulator accepts the desired "brains" as input parameters.

<div align="center">
  <img src="../assets/agentivsfsm.png" alt="Win Rates Pie Chart" width="500"/>
  <br>
  <em>Figure: Clear comparison of victories between RL agents (81%) and the FSM baseline (5%).</em>
</div>

![Heatmap Comparison](../assets/heatmap.png)
*Figure: Heatmap of direct matchups between agents expressed in terms of win rate.*
