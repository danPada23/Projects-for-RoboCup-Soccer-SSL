%% FASE 2 - nuovo
classdef RobotBilliardEnv < rl.env.MATLABEnvironment
    properties
        % Oggetti del simulatore
        Palla
        BotL
        BotR
        Campo
        PlannerL
        PlannerR % Il cervello FSM del nemico

        % --- NUOVO: Selezione dello stile di Reward ---
        % Opzioni: 'Standard', 'Continuo', 'Discreto', 'Striker',
        % 'Defender', 'Simeone', 'Zeman',
        StileReward = 'Simeone' 

        % Parametri di simulazione
        Ts = 0.01
        X_max = 0.8
        Y_max = 0.6

        % Parametri per il calcolo delle soglie
        Delta
        R_min

        % Stato interno per il Watchdog
        MaxStepsPerTurn = 1500 % 15 secondi a Ts=0.01
    end

    methods
        % --- COSTRUTTORE ---
        function this = RobotBilliardEnv()
            obsInfo = rlNumericSpec([7 1], 'LowerLimit', -1, 'UpperLimit', 1);
            obsInfo.Name = 'RobotObservations';

            actInfo = rlFiniteSetSpec(1:4);
            actInfo.Name = 'TacticalActions';

            this = this@rl.env.MATLABEnvironment(obsInfo, actInfo);
            this.setupSimulator();
        end

        % --- RESET: Inizio di ogni episodio ---
        function [InitialObservation, LoggedSignals] = reset(this)
            LoggedSignals = [];

            % Palla randomica
            this.Palla.vx = 0; this.Palla.vy = 0;
            this.Palla.y = this.Campo.safe_y(1) + rand() * (this.Campo.safe_y(2) - this.Campo.safe_y(1));
            this.Palla.x = 0.2 + rand() * 0.4;

            % Reset BotL e PlannerL (RL)
            this.BotL.x = this.Campo.safe_x(1); 
            this.BotL.y = this.Y_max/2; 
            this.BotL.theta = 0;
            this.BotL.err_sum_x = 0; this.BotL.err_sum_y = 0;
            this.PlannerL.reset();

            % Reset BotR e PlannerR (FSM)
            this.BotR.x = this.Campo.safe_x(2); 
            this.BotR.y = this.Y_max/2; 
            this.BotR.theta = pi;
            this.BotR.err_sum_x = 0; this.BotR.err_sum_y = 0;
            this.PlannerR.reset(); % Il nemico ora resetta i suoi stati logici

            InitialObservation = this.getObservation();
        end

        % --- STEP: Il cuore della logica Semi-MDP ---
        function [NextObs, Reward, IsDone, LoggedSignals] = step(this, Action)
            LoggedSignals = [];
            % 1. Comunichiamo l'azione al Planner IA (Bot Sinistro)
            switch Action
                case 1; this.PlannerL.fsm_state = 1; % PURSUE
                case 2; this.PlannerL.fsm_state = 2; % BACK
                case 3; this.PlannerL.fsm_state = 4; % CUSTOM
                case 4; this.PlannerL.fsm_state = 3; % DIFESA
            end
            
            override_triggered = false; % NUOVO: Flag per la scossa educativa
            pallaColpita = false;
            turnStepCounter = 0;
            
            % 2. Ciclo fisico
            while true
                turnStepCounter = turnStepCounter + 1;
                
                % NUOVO: Salviamo lo stato prima di interrogare il planner
                stato_pre_calcolo = this.PlannerL.fsm_state;
                
                % Calcolo Comandi: L'IA guida il sinistro, la FSM guida il destro
                [u1_L, u2_L] = this.PlannerL.decide_action(this.BotL, this.BotR, this.Palla, this.Campo, this.X_max, this.Y_max, 0.03);
                [u1_R, u2_R] = this.PlannerR.decide_action(this.BotR, this.BotL, this.Palla, this.Campo, this.X_max, this.Y_max, 0.03);
                
                % NUOVO: SENSORE DI OVERRIDE (LA TRAPPOLA EDUCATIVA)
                if ismember(this.PlannerL.fsm_state, [8, 9]) && ~ismember(stato_pre_calcolo, [8, 9])
                    override_triggered = true;
                end
                
                % Cinematica
                this.BotL.linearize_and_move(u1_L, u2_L, this.Ts);
                this.BotR.linearize_and_move(u1_R, u2_R, this.Ts); 
                % Collisioni Bot-Bot
                this.Campo.resolve_bot_bot_collision(this.BotL, this.BotR); 
                % Dinamica Palla
                this.Campo.apply_repulsion(this.Palla, this.Ts);
                this.Palla.update_dynamics(this.Ts);
                % Muri
                this.Campo.check_bot_walls(this.BotL);
                this.Campo.check_bot_walls(this.BotR); 
                % Collisioni Palla-Robot (Passando gli ID)
                this.Campo.resolve_collision(this.BotL, this.Palla, this.PlannerL.fsm_state, 1);
                this.Campo.resolve_collision(this.BotR, this.Palla, this.PlannerR.fsm_state, 2);
                
                % Flag movimento palla
                if this.Palla.is_moving()
                    pallaColpita = true;
                end
                % CONDIZIONI DI USCITA
                goal = this.Campo.check_ball_walls(this.Palla);
                if goal > 0
                    IsDone = true;
                    break;
                end
                if pallaColpita && ~this.Palla.is_moving()
                    IsDone = false;
                    break;
                end
                if turnStepCounter > this.MaxStepsPerTurn && ~pallaColpita
                    IsDone = true;
                    break;
                end
            end
            
            % NUOVO: Passiamo il flag al calcolo della reward
            Reward = this.calculateReward(goal, turnStepCounter, pallaColpita, override_triggered);
            NextObs = this.getObservation();
        end
    end

    methods (Access = private)
        function obs = getObservation(this)
            diag_campo = sqrt(this.X_max^2 + this.Y_max^2);
            pos_L = [this.BotL.x, this.BotL.y];
            pos_R = [this.BotR.x, this.BotR.y];
            pos_P = [this.Palla.x, this.Palla.y];
            porta_avv = [this.X_max, this.Y_max/2];
            mia_porta = [0, this.Y_max/2];

            dist_palla = norm(pos_P - pos_L) / diag_campo;
            ang_assoluto_palla = atan2(this.Palla.y - this.BotL.y, this.Palla.x - this.BotL.x);
            ang_relativo_palla = atan2(sin(ang_assoluto_palla - this.BotL.theta), cos(ang_assoluto_palla - this.BotL.theta)); 
            obs_ang_palla = ang_relativo_palla / pi;

            dist_avv = norm(pos_R - pos_L) / diag_campo;
            ang_assoluto_avv = atan2(this.BotR.y - this.BotL.y, this.BotR.x - this.BotL.x);
            ang_relativo_avv = atan2(sin(ang_assoluto_avv - this.BotL.theta), cos(ang_assoluto_avv - this.BotL.theta));
            obs_ang_avv = ang_relativo_avv / pi;

            dist_mia_porta = norm(mia_porta - pos_L) / this.X_max;
            dist_porta_avv = norm(porta_avv - pos_L) / this.X_max;

            dist_R_palla = norm(pos_P - pos_R);
            dist_L_palla = norm(pos_P - pos_L);
            vantaggio = (dist_R_palla - dist_L_palla) / diag_campo;

            obs = [dist_palla; obs_ang_palla; dist_avv; obs_ang_avv; dist_mia_porta; dist_porta_avv; vantaggio];
            obs = max(-1, min(1, obs));
        end

        % Helper per il calcolo del Reward (Switch Centralizzato)
        function r = calculateReward(this, goal, steps, colpita, override_triggered)
            if goal == 2 % GOL FATTO
                r = 10;
            elseif goal == 1 % GOL SUBITO / AUTOGOL
                % NUOVO: Regola Kamikaze Universale. -15 per tutti!
                r = -15; 
            elseif steps > this.MaxStepsPerTurn && ~colpita
                r = -5; % Penalità Watchdog
            else
                % Calcoli comuni per le posizioni normalizzate (0 -> 1)
                quota_palla_x = max(0, min(1, this.Palla.x / this.X_max));
                quota_bot_x = max(0, min(1, 1 - (this.BotL.x / this.X_max)));
                midfield = this.X_max / 2;

                % Selezione dello stile tramite Switch
                switch this.StileReward
                    case 'Standard'
                        % Il base senza shaping
                        r = -0.01; 

                    case 'Continuo'
                        r_base = -0.02;
                        r_off = 0.008 * quota_palla_x;
                        r_def = 0.005 * quota_bot_x;
                        r = r_base + r_off + r_def;

                    case 'Discreto'
                        r_base = -0.02;
                        r_off = 0; if this.Palla.x > midfield, r_off = 0.008; end
                        r_def = 0; if this.BotL.x < midfield,  r_def = 0.005; end
                        r = r_base + r_off + r_def;

                    case 'Striker'
                        r_base = -0.02;
                        r_off = 0.008 * quota_palla_x;
                        r = r_base + r_off;

                    case 'Defender'
                        r_base = -0.02;
                        r_def = 0.005 * quota_bot_x;
                        r = r_base + r_def;

                    case 'Simeone'
                        r_base = -0.02;
                        r_def = 0.015 * quota_bot_x *100;
                        %r_def = 0.015 * quota_bot_x *1; 
                        r_off = 0.004 * (quota_palla_x^3)*100;
                        %r_off = 0.004 * (quota_palla_x^3)*1;
                        r = r_base + r_off + r_def;

                    case 'Zeman'
                        r_base = -0.025;
                        r_off = 0.010 * quota_palla_x; 

                        y_center = this.Y_max / 2;
                        quota_y = max(0, min(1, abs(this.Palla.y - y_center) / y_center));
                        r_sponda = 0.005 * quota_y;

                        vel_palla = norm([this.Palla.vx, this.Palla.vy]);
                        quota_vel = max(0, min(1, vel_palla / 1.5));
                        r_dinamismo = 0.005 * quota_vel;

                        r = r_base + r_off + r_sponda + r_dinamismo;

                    case 'Catenaccio_Totale'
                        % Coordinate fisse della propria porta
                        porta_L_x = 0;
                        porta_L_y = this.Y_max / 2;

                        % Penalità base per il tempo che scorre
                        r_base = -0.01;

                        % ==========================================
                        % 1. ANIMA MOURINHO: Il Cono d'Ombra
                        % ==========================================
                        dx_tiro = this.Palla.x - porta_L_x;
                        dy_tiro = this.Palla.y - porta_L_y;
                        if dx_tiro > 0.05
                            m_tiro = dy_tiro / dx_tiro;
                            y_ideale = porta_L_y + m_tiro * (this.BotL.x - porta_L_x);
                            err_allineamento = abs(this.BotL.y - y_ideale);
                            quota_allineamento = max(0, 1 - (err_allineamento / (this.Y_max/2)));
                            r_cono = 0.015 * quota_allineamento; 
                        else
                            r_cono = 0; 
                        end

                        % Posizione rispetto alla linea della palla
                        if this.BotL.x < this.Palla.x - 0.05
                            r_dietro_palla = 1; % Perfetto, è a protezione
                        else
                            r_dietro_palla = -1; % È stato saltato!
                        end

                        % Zona di competenza (Trequarti difensiva)
                        dist_da_porta = this.BotL.x;
                        if dist_da_porta > 0.10 && dist_da_porta < 0.35
                            r_zona = 0.005;
                        else
                            r_zona = 0;
                        end

                        % ==========================================
                        % 2. ANIMA ALLEGRI: Prevenzione Autogol
                        % ==========================================
                        r_pericolo = 0;
                        % Se il bot è "oltre" la palla (verso l'attacco)
                        if this.BotL.x > this.Palla.x
                            % Controlliamo se è pericolosamente vicino alla palla
                            dist_palla_bot = norm([this.BotL.x - this.Palla.x, this.BotL.y - this.Palla.y]);
                            if dist_palla_bot < 0.15
                                % È nel posto sbagliato, dal lato sbagliato, e troppo vicino!
                                r_pericolo = -0.025; 
                            end
                        end

                        % Somma finale di tutti i premi e penalità
                        r = r_base + r_cono + r_dietro_palla + r_zona + r_pericolo;

                    otherwise
                        r = -0.01; % Fallback di sicurezza
                    % NUOVO: Applichiamo la Scossa Educativa (Valida per tutti gli stili)
                    if override_triggered
                    r = r - 0.5;
                    end
                end
            end
        end

        function setupSimulator(this)
            A = 0.025; b = 0.03; d = 0.0316;
            this.Delta = 0.115; this.R_min = 2 * this.Delta;
            this.Campo = Field([0 0.8], [0 0.6], [d 0.8-d], [d 0.6-d], 0.25, 0.05);
            this.Palla = Ball(0.4, 0.3, 0.02, 0.0027);

            % Inizializziamo entrambi i bot e i loro rispettivi Planner!
            this.BotL = Bot(0.05, 0.3, 0, b, d, A, 1.5, 0.5*1.5*A^2, 0.8, 'PID', [4, 0.5]);
            this.PlannerL = Planner(this.Ts, this.R_min, 3*this.Delta, 2*this.Delta, this.Delta, 0.05, 0.3, 1);

            this.BotR = Bot(0.75, 0.3, pi, b, d, A, 1.5, 0.5*1.5*A^2, 0.8, 'PID', [4, 0.5]);
            this.PlannerR = Planner(this.Ts, this.R_min, 3*this.Delta, 2*this.Delta, this.Delta, 0.75, 0.3, -1);
        end
    end
end

% %% FASE 1 - NUOVO
% classdef RobotBilliardEnv < rl.env.MATLABEnvironment
%     properties
%         % Oggetti del simulatore
%         Palla
%         BotL
%         BotR
%         Campo
%         PlannerL
%         % Parametri di simulazione
%         Ts = 0.01
%         X_max = 0.8
%         Y_max = 0.6
%         % Parametri per il calcolo delle soglie
%         Delta
%         R_min
%         % Stato interno per il Watchdog
%         MaxStepsPerTurn = 1500 % 15 secondi a Ts=0.01
%     end
%     methods
%         % --- COSTRUTTORE ---
%         function this = RobotBilliardEnv()
%             % 1. Definiamo lo spazio delle osservazioni (7 features)
%             obsInfo = rlNumericSpec([7 1], 'LowerLimit', -1, 'UpperLimit', 1);
%             obsInfo.Name = 'RobotObservations';
%             % 2. Definiamo lo spazio delle azioni (4 macro-azioni strategiche)
%             actInfo = rlFiniteSetSpec(1:4);
%             actInfo.Name = 'TacticalActions';
%             % 3. Inizializziamo la classe base
%             this = this@rl.env.MATLABEnvironment(obsInfo, actInfo);
%             % 4. Setup iniziale dei parametri fisici
%             this.setupSimulator();
%         end
% 
%         % --- RESET: Inizio di ogni episodio ---
%         function [InitialObservation, LoggedSignals] = reset(this)
%             LoggedSignals = [];
% 
%             % Posizionamento randomico della palla 
%             this.Palla.vx = 0; this.Palla.vy = 0;
%             this.Palla.y = this.Campo.safe_y(1) + rand() * (this.Campo.safe_y(2) - this.Campo.safe_y(1));
%             this.Palla.x = 0.2 + rand() * 0.4; % Palla al centro
% 
%             % Reset BotL e PlannerL (Pulizia profonda come in Fase 0)
%             this.BotL.x = this.Campo.safe_x(1); 
%             this.BotL.y = this.Y_max/2; 
%             this.BotL.theta = 0;
%             this.BotL.err_sum_x = 0; 
%             this.BotL.err_sum_y = 0;
%             this.PlannerL.reset();
%             this.PlannerL.fsm_state = 0; % Assicuriamoci che parta da 0
% 
%             % Reset BotR (Wanderer) e svuotamento del target
%             this.BotR.x = this.Campo.safe_x(2); 
%             this.BotR.y = this.Y_max/2; 
%             this.BotR.theta = pi;
%             this.BotR.err_sum_x = 0; 
%             this.BotR.err_sum_y = 0;
%             this.BotR.target_x = []; % Fondamentale per evitare crash post-gol
%             this.BotR.target_y = [];
% 
%             % Restituiamo la prima osservazione
%             InitialObservation = this.getObservation();
%         end
% 
%         % --- STEP: Il cuore della logica Semi-MDP ---
%         function [NextObs, Reward, IsDone, LoggedSignals] = step(this, Action)
%             LoggedSignals = [];
% 
%             % 1. MAPPATURA MACRO-AZIONE
%             switch Action
%                 case 1; this.PlannerL.fsm_state = 1; % PURSUE -> ATTACCO
%                 case 2; this.PlannerL.fsm_state = 2; % BACK
%                 case 3; this.PlannerL.fsm_state = 4; % CUSTOM
%                 case 4; this.PlannerL.fsm_state = 3; % DIFESA
%             end
% 
%             % Flag per rilevare l'override del Planner (Fase 0)
%             override_triggered = false; 
%             pallaColpita = false;
%             turnStepCounter = 0;
% 
%             % 2. CICLO FISICO
%             while true
%                 turnStepCounter = turnStepCounter + 1;
% 
%                 % Salviamo lo stato prima di interrogare il planner
%                 stato_pre_calcolo = this.PlannerL.fsm_state;
% 
%                 % Eseguiamo i calcoli per il BotL
%                 [u1_L, u2_L] = this.PlannerL.decide_action(this.BotL, this.BotR, this.Palla, this.Campo, this.X_max, this.Y_max, 0.03);
% 
%                 % --- SENSORE DI OVERRIDE (LA TRAPPOLA EDUCATIVA) ---
%                 if ismember(this.PlannerL.fsm_state, [8, 9]) && ~ismember(stato_pre_calcolo, [8, 9])
%                     override_triggered = true;
%                 end
% 
%                 % --- COMPORTAMENTO BOT R (WANDERER FASE 1) ---
%                 if this.Palla.is_moving()
%                     u1_R = 0; 
%                     u2_R = 0;
%                     this.BotR.err_sum_x = 0; 
%                     this.BotR.err_sum_y = 0;
%                 else
%                     % 1. Definiamo l'area di movimento (la metà campo destra)
%                     area_nemico_x = [this.X_max/2, this.Campo.safe_x(2)];
%                     area_nemico_y = [this.Campo.safe_y(1), this.Campo.safe_y(2)];
%                     % 2. Definiamo l'ostacolo da evitare (il nostro Agente)
%                     ostacoli_nemico = this.BotL;
%                     % 3. Chiamiamo la funzione di movimento casuale
%                     [u1_R, u2_R] = this.BotR.compute_wander_control(area_nemico_x, area_nemico_y, ostacoli_nemico);
%                 end
% 
%                 % Cinematica
%                 this.BotL.linearize_and_move(u1_L, u2_L, this.Ts);
%                 this.BotR.linearize_and_move(u1_R, u2_R, this.Ts); 
% 
%                 % Risoluzione anti-compenetrazione tra i due robot
%                 this.Campo.resolve_bot_bot_collision(this.BotL, this.BotR); 
% 
%                 % Dinamica Palla
%                 this.Campo.apply_repulsion(this.Palla, this.Ts);
%                 this.Palla.update_dynamics(this.Ts);
% 
%                 % Muri e Collisioni
%                 this.Campo.check_bot_walls(this.BotL);
%                 this.Campo.check_bot_walls(this.BotR); 
%                 this.Campo.resolve_collision(this.BotL, this.Palla, this.PlannerL.fsm_state);
%                 this.Campo.resolve_collision(this.BotR, this.Palla); % BotR usa la fisica base
% 
%                 % Controllo se la palla ha iniziato a muoversi
%                 if this.Palla.is_moving()
%                     pallaColpita = true;
%                 end
% 
%                 % --- CONDIZIONI DI USCITA ---
%                 goal = this.Campo.check_ball_walls(this.Palla);
% 
%                 if goal > 0 % Gol o Autogol
%                     IsDone = true;
%                     break;
%                 end
% 
%                 if pallaColpita && ~this.Palla.is_moving() % Palla ferma
%                     IsDone = false;
%                     break;
%                 end
% 
%                 if turnStepCounter > this.MaxStepsPerTurn && ~pallaColpita % Timeout
%                     IsDone = true;
%                     break;
%                 end
%             end
% 
%             % 3. Calcolo del Reward passando il flag di override
%             Reward = this.calculateReward(goal, turnStepCounter, pallaColpita, override_triggered);
%             NextObs = this.getObservation();
%         end
%     end
% 
%     methods (Access = private)
%         function obs = getObservation(this)
%             diag_campo = sqrt(this.X_max^2 + this.Y_max^2);
%             pos_L = [this.BotL.x, this.BotL.y];
%             pos_R = [this.BotR.x, this.BotR.y];
%             pos_P = [this.Palla.x, this.Palla.y];
%             porta_avv = [this.X_max, this.Y_max/2];
%             mia_porta = [0, this.Y_max/2];
% 
%             dist_palla = norm(pos_P - pos_L) / diag_campo;
%             ang_assoluto_palla = atan2(this.Palla.y - this.BotL.y, this.Palla.x - this.BotL.x);
%             ang_relativo_palla = ang_assoluto_palla - this.BotL.theta;
%             ang_relativo_palla = atan2(sin(ang_relativo_palla), cos(ang_relativo_palla)); 
%             obs_ang_palla = ang_relativo_palla / pi;
% 
%             dist_avv = norm(pos_R - pos_L) / diag_campo;
%             ang_assoluto_avv = atan2(this.BotR.y - this.BotL.y, this.BotR.x - this.BotL.x);
%             ang_relativo_avv = ang_assoluto_avv - this.BotL.theta;
%             ang_relativo_avv = atan2(sin(ang_relativo_avv), cos(ang_relativo_avv));
%             obs_ang_avv = ang_relativo_avv / pi;
% 
%             dist_mia_porta = norm(mia_porta - pos_L) / this.X_max;
%             dist_porta_avv = norm(porta_avv - pos_L) / this.X_max;
%             dist_R_palla = norm(pos_P - pos_R);
%             dist_L_palla = norm(pos_P - pos_L);
%             vantaggio = (dist_R_palla - dist_L_palla) / diag_campo;
% 
%             obs = [dist_palla; obs_ang_palla; dist_avv; obs_ang_avv; dist_mia_porta; dist_porta_avv; vantaggio];
%             obs = max(-1, min(1, obs));
%         end
% 
%         % Helper per il calcolo del Reward (AGGIORNATO FASE 0 + FASE 1)
%         function r = calculateReward(this, goal, steps, colpita, override_triggered)
%             if goal == 2 % GOL FATTO (Porta destra per BotL)
%                 r = 10;
%             elseif goal == 1 % GOL SUBITO / AUTOGOL
%                 r = -15; % PENALITÀ SEVERA
%             elseif steps > this.MaxStepsPerTurn && ~colpita
%                 r = -5; % Penalità Watchdog
%             else
%                 r = -0.01; % Piccola penalità temporale per incentivare la velocità
% 
%                 % LA SCOSSA EDUCATIVA
%                 if override_triggered
%                     r = r - 0.5; % Bastonata se ha forzato un ESCAPE o SPAZZATA
%                 end
%             end
%         end
% 
%         % Inizializzazione oggetti
%         function setupSimulator(this)
%             A = 0.025; b = 0.03; d = 0.0316;
%             this.Delta = 0.115; this.R_min = 2 * this.Delta;
%             this.Campo = Field([0 0.8], [0 0.6], [d 0.8-d], [d 0.6-d], 0.25, 0.05);
%             this.Palla = Ball(0.4, 0.3, 0.02, 0.0027);
%             this.BotL = Bot(0.05, 0.3, 0, b, d, A, 1.5, 0.5*1.5*A^2, 0.8, 'PID', [4, 0.5]);
%             this.BotR = Bot(0.75, 0.3, pi, b, d, A, 1.5, 0.5*1.5*A^2, 0.8, 'PID', [4, 0.5]);
%             this.PlannerL = Planner(this.Ts, this.R_min, 3*this.Delta, 2*this.Delta, this.Delta, 0.05, 0.3, 1);
%         end
%     end
% end



% %% Fase 0 - NUOVO
% classdef RobotBilliardEnv < rl.env.MATLABEnvironment
%     properties
%         % Oggetti del simulatore
%         Palla
%         BotL
%         BotR
%         Campo
%         PlannerL
%         PlannerR
% 
%         % Parametri di simulazione
%         Ts = 0.01
%         X_max = 0.8
%         Y_max = 0.6
% 
%         % Parametri per il calcolo delle soglie
%         Delta
%         R_min
% 
%         % Stato interno per il Watchdog
%         MaxStepsPerTurn = 1500 % 15 secondi a Ts=0.01
%     end
% 
%     methods
%         % --- COSTRUTTORE ---
%         function this = RobotBilliardEnv()
%             % 1. Spazio delle osservazioni (7 features)
%             obsInfo = rlNumericSpec([7 1], 'LowerLimit', -1, 'UpperLimit', 1);
%             obsInfo.Name = 'RobotObservations';
% 
%             % 2. Spazio delle azioni (4 macro-azioni strategiche)
%             actInfo = rlFiniteSetSpec(1:4);
%             actInfo.Name = 'TacticalActions';
% 
%             % 3. Inizializziamo la classe base
%             this = this@rl.env.MATLABEnvironment(obsInfo, actInfo);
% 
%             % 4. Setup iniziale dei parametri fisici
%             this.setupSimulator();
%         end
% 
%         % --- RESET: Inizio di ogni episodio ---
%         function [InitialObservation, LoggedSignals] = reset(this)
%             LoggedSignals = [];
% 
%             % Posizionamento randomico della palla (Fase 0: BotL vs Campo Vuoto)
%             this.Palla.vx = 0; this.Palla.vy = 0;
%             this.Palla.y = this.Campo.safe_y(1) + rand() * (this.Campo.safe_y(2) - this.Campo.safe_y(1));
%             this.Palla.x = 0.2 + rand() * 0.4; % Palla al centro
% 
%             % Reset BotL e PlannerL (Pulizia profonda)
%             this.BotL.x = this.Campo.safe_x(1); 
%             this.BotL.y = this.Y_max/2; 
%             this.BotL.theta = 0;
%             this.BotL.err_sum_x = 0; 
%             this.BotL.err_sum_y = 0;
%             this.PlannerL.reset();
%             this.PlannerL.fsm_state = 0; % Assicuriamoci che parta da 0
% 
%             % Reset BotR (la "statua" torna al suo posto)
%             this.BotR.x = this.Campo.safe_x(2); 
%             this.BotR.y = this.Y_max/2; 
%             this.BotR.theta = pi;
%             this.BotR.err_sum_x = 0; 
%             this.BotR.err_sum_y = 0;
% 
%             InitialObservation = this.getObservation();
%         end
% 
%         % --- STEP: Il cuore della logica Semi-MDP ---
%         function [NextObs, Reward, IsDone, LoggedSignals] = step(this, Action)
%             LoggedSignals = [];
% 
%             % 1. MAPPATURA MACRO-AZIONE
%             % L'RL comanda l'intenzione, la FSM la eseguirà
%             switch Action
%                 case 1; this.PlannerL.fsm_state = 1; % PURSUE (poi andrà in ACTION->ATTACCO)
%                 case 2; this.PlannerL.fsm_state = 2; % BACK
%                 case 3; this.PlannerL.fsm_state = 4; % CUSTOM (Riposizionamento intelligente)
%                 case 4; this.PlannerL.fsm_state = 3; % DIFESA
%             end
% 
%             % Flag per rilevare se l'RL ha fatto una "mossa stupida"
%             override_triggered = false; 
%             pallaColpita = false;
%             turnStepCounter = 0;
% 
%             % 2. CICLO FISICO: Esecuzione Autonoma del Planner
%             while true
%                 turnStepCounter = turnStepCounter + 1;
% 
%                 % Salviamo lo stato prima di interrogare il planner
%                 stato_pre_calcolo = this.PlannerL.fsm_state;
% 
%                 % Il Cervelletto (Planner) valuta la situazione e decide i motori
%                 [u1_L, u2_L] = this.PlannerL.decide_action(this.BotL, this.BotR, this.Palla, this.Campo, this.X_max, this.Y_max, 0.03);
% 
%                 % --- SENSORE DI OVERRIDE (LA TRAPPOLA EDUCATIVA) ---
%                 % Se lo stato è improvvisamente diventato 8 (Escape) o 9 (Spazzata)
%                 % significa che l'azione dell'RL stava per causare un disastro e il planner l'ha salvato.
%                 if ismember(this.PlannerL.fsm_state, [8, 9]) && ~ismember(stato_pre_calcolo, [8, 9])
%                     override_triggered = true;
%                 end
% 
%                 % Esecuzione fisica
%                 this.BotL.linearize_and_move(u1_L, u2_L, this.Ts);
%                 this.Campo.apply_repulsion(this.Palla, this.Ts);
%                 this.Palla.update_dynamics(this.Ts);
%                 this.Campo.check_bot_walls(this.BotL);
%                 this.Campo.resolve_collision(this.BotL, this.Palla, this.PlannerL.fsm_state);
% 
%                 if this.Palla.is_moving()
%                     pallaColpita = true;
%                 end
% 
%                 % --- CONDIZIONI DI USCITA ---
%                 goal = this.Campo.check_ball_walls(this.Palla);
% 
%                 if goal > 0 % Gol o Autogol
%                     IsDone = true;
%                     break;
%                 end
% 
%                 if pallaColpita && ~this.Palla.is_moving() % Palla ferma dopo tocco
%                     IsDone = false;
%                     break;
%                 end
% 
%                 if turnStepCounter > this.MaxStepsPerTurn && ~pallaColpita % Timeout
%                     IsDone = true;
%                     break;
%                 end
%             end
% 
%             % 3. Calcolo del Reward passando il flag di override
%             Reward = this.calculateReward(goal, turnStepCounter, pallaColpita, override_triggered);
%             NextObs = this.getObservation();
%         end
%     end
% 
%     methods (Access = private)
%         function obs = getObservation(this)
%             diag_campo = sqrt(this.X_max^2 + this.Y_max^2);
%             pos_L = [this.BotL.x, this.BotL.y];
%             pos_R = [this.BotR.x, this.BotR.y];
%             pos_P = [this.Palla.x, this.Palla.y];
%             porta_avv = [this.X_max, this.Y_max/2];
%             mia_porta = [0, this.Y_max/2];
% 
%             dist_palla = norm(pos_P - pos_L) / diag_campo;
%             ang_assoluto_palla = atan2(this.Palla.y - this.BotL.y, this.Palla.x - this.BotL.x);
%             ang_relativo_palla = ang_assoluto_palla - this.BotL.theta;
%             ang_relativo_palla = atan2(sin(ang_relativo_palla), cos(ang_relativo_palla)); 
%             obs_ang_palla = ang_relativo_palla / pi;
%             dist_avv = norm(pos_R - pos_L) / diag_campo;
%             ang_assoluto_avv = atan2(this.BotR.y - this.BotL.y, this.BotR.x - this.BotL.x);
%             ang_relativo_avv = ang_assoluto_avv - this.BotL.theta;
%             ang_relativo_avv = atan2(sin(ang_relativo_avv), cos(ang_relativo_avv));
%             obs_ang_avv = ang_relativo_avv / pi;
%             dist_mia_porta = norm(mia_porta - pos_L) / this.X_max;
%             dist_porta_avv = norm(porta_avv - pos_L) / this.X_max;
%             dist_R_palla = norm(pos_P - pos_R);
%             dist_L_palla = norm(pos_P - pos_L);
%             vantaggio = (dist_R_palla - dist_L_palla) / diag_campo;
% 
%             obs = [dist_palla; obs_ang_palla; dist_avv; obs_ang_avv; dist_mia_porta; dist_porta_avv; vantaggio];
%             obs = max(-1, min(1, obs));
%         end
% 
%         % Helper per il calcolo del Reward (AGGIORNATO)
%         function r = calculateReward(this, goal, steps, colpita, override_triggered)
%             if goal == 2 % GOL FATTO
%                 r = 10;
%             elseif goal == 1 % GOL SUBITO / AUTOGOL
%                 r = -15; % PENALITÀ SEVERA DEFINITIVA
%             elseif steps > this.MaxStepsPerTurn && ~colpita
%                 r = -5; % Penalità Watchdog
%             else
%                 % Reward base continuo
%                 r = -0.01; 
% 
%                 % LA SCOSSA EDUCATIVA
%                 if override_triggered
%                     r = r - 0.5; % Bastonata se ha forzato un ESCAPE o SPAZZATA
%                 end
%             end
%         end
% 
%         function setupSimulator(this)
%             A = 0.025; b = 0.03; d = 0.0316;
%             this.Delta = 0.115; this.R_min = 2 * this.Delta;
%             this.Campo = Field([0 0.8], [0 0.6], [d 0.8-d], [d 0.6-d], 0.25, 0.05);
%             this.Palla = Ball(0.4, 0.3, 0.02, 0.0027);
%             this.BotL = Bot(0.05, 0.3, 0, b, d, A, 1.5, 0.5*1.5*A^2, 0.8, 'PID', [4, 0.5]);
%             this.BotR = Bot(0.75, 0.3, pi, b, d, A, 1.5, 0.5*1.5*A^2, 0.8, 'PID', [4, 0.5]);
%             this.PlannerL = Planner(this.Ts, this.R_min, 3*this.Delta, 2*this.Delta, this.Delta, 0.05, 0.3, 1);
%             this.PlannerR = Planner(this.Ts, this.R_min, 3*this.Delta, 2*this.Delta, this.Delta, 0.75, 0.3, -1);
%         end
%     end
% end

% %% FASE 2 (ia vs fsm)
% classdef RobotBilliardEnv < rl.env.MATLABEnvironment
%     properties
%         % Oggetti del simulatore
%         Palla
%         BotL
%         BotR
%         Campo
%         PlannerL
%         PlannerR % Il cervello FSM del nemico
% 
%         % --- NUOVO: Selezione dello stile di Reward ---
%         % Opzioni: 'Standard', 'Continuo', 'Discreto', 'Striker',
%         % 'Defender', 'Simeone', 'Zeman',
%         StileReward = 'Catenaccio_Totale' 
% 
%         % Parametri di simulazione
%         Ts = 0.01
%         X_max = 0.8
%         Y_max = 0.6
% 
%         % Parametri per il calcolo delle soglie
%         Delta
%         R_min
% 
%         % Stato interno per il Watchdog
%         MaxStepsPerTurn = 1500 % 15 secondi a Ts=0.01
%     end
% 
%     methods
%         % --- COSTRUTTORE ---
%         function this = RobotBilliardEnv()
%             obsInfo = rlNumericSpec([7 1], 'LowerLimit', -1, 'UpperLimit', 1);
%             obsInfo.Name = 'RobotObservations';
% 
%             actInfo = rlFiniteSetSpec(1:4);
%             actInfo.Name = 'TacticalActions';
% 
%             this = this@rl.env.MATLABEnvironment(obsInfo, actInfo);
%             this.setupSimulator();
%         end
% 
%         % --- RESET: Inizio di ogni episodio ---
%         function [InitialObservation, LoggedSignals] = reset(this)
%             LoggedSignals = [];
% 
%             % Palla randomica
%             this.Palla.vx = 0; this.Palla.vy = 0;
%             this.Palla.y = this.Campo.safe_y(1) + rand() * (this.Campo.safe_y(2) - this.Campo.safe_y(1));
%             this.Palla.x = 0.2 + rand() * 0.4;
% 
%             % Reset BotL e PlannerL (RL)
%             this.BotL.x = this.Campo.safe_x(1); 
%             this.BotL.y = this.Y_max/2; 
%             this.BotL.theta = 0;
%             this.BotL.err_sum_x = 0; this.BotL.err_sum_y = 0;
%             this.PlannerL.reset();
% 
%             % Reset BotR e PlannerR (FSM)
%             this.BotR.x = this.Campo.safe_x(2); 
%             this.BotR.y = this.Y_max/2; 
%             this.BotR.theta = pi;
%             this.BotR.err_sum_x = 0; this.BotR.err_sum_y = 0;
%             this.PlannerR.reset(); % Il nemico ora resetta i suoi stati logici
% 
%             InitialObservation = this.getObservation();
%         end
% 
%         % --- STEP: Il cuore della logica Semi-MDP ---
%         function [NextObs, Reward, IsDone, LoggedSignals] = step(this, Action)
%             LoggedSignals = [];
% 
%             % 1. Comunichiamo l'azione al Planner IA (Bot Sinistro)
%             switch Action
%                 case 1; this.PlannerL.fsm_state = 1; % PURSUE
%                 case 2; this.PlannerL.fsm_state = 2; % BACK
%                 case 3; this.PlannerL.fsm_state = 4; % CUSTOM
%                 case 4; this.PlannerL.fsm_state = 3; % DIFESA
%             end
% 
%             pallaColpita = false;
%             turnStepCounter = 0;
% 
%             % 2. Ciclo fisico
%             while true
%                 turnStepCounter = turnStepCounter + 1;
% 
%                 % Calcolo Comandi: L'IA guida il sinistro, la FSM guida il destro in autonomia
%                 [u1_L, u2_L] = this.PlannerL.decide_action(this.BotL, this.BotR, this.Palla, this.Campo, this.X_max, this.Y_max, 0.03);
%                 [u1_R, u2_R] = this.PlannerR.decide_action(this.BotR, this.BotL, this.Palla, this.Campo, this.X_max, this.Y_max, 0.03);
% 
%                 % Cinematica
%                 this.BotL.linearize_and_move(u1_L, u2_L, this.Ts);
%                 this.BotR.linearize_and_move(u1_R, u2_R, this.Ts); 
% 
%                 % Collisioni Bot-Bot
%                 this.Campo.resolve_bot_bot_collision(this.BotL, this.BotR); 
% 
%                 % Dinamica Palla
%                 this.Campo.apply_repulsion(this.Palla, this.Ts);
%                 this.Palla.update_dynamics(this.Ts);
% 
%                 % Muri
%                 this.Campo.check_bot_walls(this.BotL);
%                 this.Campo.check_bot_walls(this.BotR); 
% 
%                 % Collisioni Palla-Robot
%                 this.Campo.resolve_collision(this.BotL, this.Palla, this.PlannerL.fsm_state);
%                 this.Campo.resolve_collision(this.BotR, this.Palla, this.PlannerR.fsm_state); 
% 
%                 % Flag movimento palla (Usa il metodo unificato!)
%                 if this.Palla.is_moving()
%                     pallaColpita = true;
%                 end
% 
%                 % CONDIZIONI DI USCITA
%                 goal = this.Campo.check_ball_walls(this.Palla);
% 
%                 if goal > 0
%                     IsDone = true;
%                     break;
%                 end
% 
%                 if pallaColpita && ~this.Palla.is_moving()
%                     IsDone = false;
%                     break;
%                 end
% 
%                 if turnStepCounter > this.MaxStepsPerTurn && ~pallaColpita
%                     IsDone = true;
%                     break;
%                 end
%             end
% 
%             Reward = this.calculateReward(goal, turnStepCounter, pallaColpita);
%             NextObs = this.getObservation();
%         end
%     end
% 
%     methods (Access = private)
%         function obs = getObservation(this)
%             diag_campo = sqrt(this.X_max^2 + this.Y_max^2);
%             pos_L = [this.BotL.x, this.BotL.y];
%             pos_R = [this.BotR.x, this.BotR.y];
%             pos_P = [this.Palla.x, this.Palla.y];
%             porta_avv = [this.X_max, this.Y_max/2];
%             mia_porta = [0, this.Y_max/2];
% 
%             dist_palla = norm(pos_P - pos_L) / diag_campo;
%             ang_assoluto_palla = atan2(this.Palla.y - this.BotL.y, this.Palla.x - this.BotL.x);
%             ang_relativo_palla = atan2(sin(ang_assoluto_palla - this.BotL.theta), cos(ang_assoluto_palla - this.BotL.theta)); 
%             obs_ang_palla = ang_relativo_palla / pi;
% 
%             dist_avv = norm(pos_R - pos_L) / diag_campo;
%             ang_assoluto_avv = atan2(this.BotR.y - this.BotL.y, this.BotR.x - this.BotL.x);
%             ang_relativo_avv = atan2(sin(ang_assoluto_avv - this.BotL.theta), cos(ang_assoluto_avv - this.BotL.theta));
%             obs_ang_avv = ang_relativo_avv / pi;
% 
%             dist_mia_porta = norm(mia_porta - pos_L) / this.X_max;
%             dist_porta_avv = norm(porta_avv - pos_L) / this.X_max;
% 
%             dist_R_palla = norm(pos_P - pos_R);
%             dist_L_palla = norm(pos_P - pos_L);
%             vantaggio = (dist_R_palla - dist_L_palla) / diag_campo;
% 
%             obs = [dist_palla; obs_ang_palla; dist_avv; obs_ang_avv; dist_mia_porta; dist_porta_avv; vantaggio];
%             obs = max(-1, min(1, obs));
%         end
% 
%         % Helper per il calcolo del Reward (Switch Centralizzato)
%         function r = calculateReward(this, goal, steps, colpita)
%             if goal == 2 % GOL FATTO
%                 r = 10;
%             elseif goal == 1 % GOL SUBITO / AUTOGOL
%                 % Controllo per la penalità maggiorata stile Allegri
%                 if strcmp(this.StileReward, 'Catenaccio_Totale')
%                     r = -15;
%                 else
%                     r = -10;
%                 end
%             elseif steps > this.MaxStepsPerTurn && ~colpita
%                 r = -5; % Penalità Watchdog
%             else
%                 % Calcoli comuni per le posizioni normalizzate (0 -> 1)
%                 quota_palla_x = max(0, min(1, this.Palla.x / this.X_max));
%                 quota_bot_x = max(0, min(1, 1 - (this.BotL.x / this.X_max)));
%                 midfield = this.X_max / 2;
% 
%                 % Selezione dello stile tramite Switch
%                 switch this.StileReward
%                     case 'Standard'
%                         % Il base senza shaping
%                         r = -0.01; 
% 
%                     case 'Continuo'
%                         r_base = -0.02;
%                         r_off = 0.008 * quota_palla_x;
%                         r_def = 0.005 * quota_bot_x;
%                         r = r_base + r_off + r_def;
% 
%                     case 'Discreto'
%                         r_base = -0.02;
%                         r_off = 0; if this.Palla.x > midfield, r_off = 0.008; end
%                         r_def = 0; if this.BotL.x < midfield,  r_def = 0.005; end
%                         r = r_base + r_off + r_def;
% 
%                     case 'Striker'
%                         r_base = -0.02;
%                         r_off = 0.008 * quota_palla_x;
%                         r = r_base + r_off;
% 
%                     case 'Defender'
%                         r_base = -0.02;
%                         r_def = 0.005 * quota_bot_x;
%                         r = r_base + r_def;
% 
%                     case 'Simeone'
%                         r_base = -0.02;
%                         r_def = 0.015 * quota_bot_x; 
%                         r_off = 0.004 * (quota_palla_x^3); 
%                         r = r_base + r_off + r_def;
% 
%                     case 'Zeman'
%                         r_base = -0.025;
%                         r_off = 0.010 * quota_palla_x; 
% 
%                         y_center = this.Y_max / 2;
%                         quota_y = max(0, min(1, abs(this.Palla.y - y_center) / y_center));
%                         r_sponda = 0.005 * quota_y;
% 
%                         vel_palla = norm([this.Palla.vx, this.Palla.vy]);
%                         quota_vel = max(0, min(1, vel_palla / 1.5));
%                         r_dinamismo = 0.005 * quota_vel;
% 
%                         r = r_base + r_off + r_sponda + r_dinamismo;
% 
%                     case 'Catenaccio_Totale'
%                         % Coordinate fisse della propria porta
%                         porta_L_x = 0;
%                         porta_L_y = this.Y_max / 2;
% 
%                         % Penalità base per il tempo che scorre
%                         r_base = -0.01;
% 
%                         % ==========================================
%                         % 1. ANIMA MOURINHO: Il Cono d'Ombra
%                         % ==========================================
%                         dx_tiro = this.Palla.x - porta_L_x;
%                         dy_tiro = this.Palla.y - porta_L_y;
%                         if dx_tiro > 0.05
%                             m_tiro = dy_tiro / dx_tiro;
%                             y_ideale = porta_L_y + m_tiro * (this.BotL.x - porta_L_x);
%                             err_allineamento = abs(this.BotL.y - y_ideale);
%                             quota_allineamento = max(0, 1 - (err_allineamento / (this.Y_max/2)));
%                             r_cono = 0.015 * quota_allineamento; 
%                         else
%                             r_cono = 0; 
%                         end
% 
%                         % Posizione rispetto alla linea della palla
%                         if this.BotL.x < this.Palla.x - 0.05
%                             r_dietro_palla = 0.010; % Perfetto, è a protezione
%                         else
%                             r_dietro_palla = -0.010; % È stato saltato!
%                         end
% 
%                         % Zona di competenza (Trequarti difensiva)
%                         dist_da_porta = this.BotL.x;
%                         if dist_da_porta > 0.10 && dist_da_porta < 0.35
%                             r_zona = 0.005;
%                         else
%                             r_zona = 0;
%                         end
% 
%                         % ==========================================
%                         % 2. ANIMA ALLEGRI: Prevenzione Autogol
%                         % ==========================================
%                         r_pericolo = 0;
%                         % Se il bot è "oltre" la palla (verso l'attacco)
%                         if this.BotL.x > this.Palla.x
%                             % Controlliamo se è pericolosamente vicino alla palla
%                             dist_palla_bot = norm([this.BotL.x - this.Palla.x, this.BotL.y - this.Palla.y]);
%                             if dist_palla_bot < 0.15
%                                 % È nel posto sbagliato, dal lato sbagliato, e troppo vicino!
%                                 r_pericolo = -0.025; 
%                             end
%                         end
% 
%                         % Somma finale di tutti i premi e penalità
%                         r = r_base + r_cono + r_dietro_palla + r_zona + r_pericolo;
% 
%                     otherwise
%                         r = -0.01; % Fallback di sicurezza
%                 end
%             end
%         end
% 
%         function setupSimulator(this)
%             A = 0.025; b = 0.03; d = 0.0316;
%             this.Delta = 0.115; this.R_min = 2 * this.Delta;
%             this.Campo = Field([0 0.8], [0 0.6], [d 0.8-d], [d 0.6-d], 0.25, 0.05);
%             this.Palla = Ball(0.4, 0.3, 0.02, 0.0027);
% 
%             % Inizializziamo entrambi i bot e i loro rispettivi Planner!
%             this.BotL = Bot(0.05, 0.3, 0, b, d, A, 1.5, 0.5*1.5*A^2, 0.8, 'PID', [4, 0.5]);
%             this.PlannerL = Planner(this.Ts, this.R_min, 3*this.Delta, 2*this.Delta, this.Delta, 0.05, 0.3, 1);
% 
%             this.BotR = Bot(0.75, 0.3, pi, b, d, A, 1.5, 0.5*1.5*A^2, 0.8, 'PID', [4, 0.5]);
%             this.PlannerR = Planner(this.Ts, this.R_min, 3*this.Delta, 2*this.Delta, this.Delta, 0.75, 0.3, -1);
%         end
%     end
% end


% %% FASE 1 (da FASE 0)
% classdef RobotBilliardEnv < rl.env.MATLABEnvironment
% 
%     properties
%         % Oggetti del simulatore
%         Palla
%         BotL
%         BotR
%         Campo
%         PlannerL
% 
%         % Parametri di simulazione
%         Ts = 0.01
%         X_max = 0.8
%         Y_max = 0.6
% 
%         % Parametri per il calcolo delle soglie
%         Delta
%         R_min
% 
%         % Stato interno per il Watchdog
%         MaxStepsPerTurn = 1500 % 15 secondi a Ts=0.01
%     end
% 
%     methods
%         % --- COSTRUTTORE ---
%         function this = RobotBilliardEnv()
%             % 1. Definiamo lo spazio delle osservazioni (7 features)
%             obsInfo = rlNumericSpec([7 1], 'LowerLimit', -1, 'UpperLimit', 1);
%             obsInfo.Name = 'RobotObservations';
% 
%             % 2. Definiamo lo spazio delle azioni (4 macro-azioni)
%             actInfo = rlFiniteSetSpec(1:4);
%             actInfo.Name = 'TacticalActions';
% 
%             % 3. Inizializziamo la classe base
%             this = this@rl.env.MATLABEnvironment(obsInfo, actInfo);
% 
%             % 4. Setup iniziale dei parametri fisici
%             this.setupSimulator();
%         end
% 
%         % --- RESET: Inizio di ogni episodio ---
%         function [InitialObservation, LoggedSignals] = reset(this)
%             LoggedSignals = [];
% 
%             % Posizionamento randomico della palla 
%             this.Palla.vx = 0; this.Palla.vy = 0;
%             this.Palla.y = this.Campo.safe_y(1) + rand() * (this.Campo.safe_y(2) - this.Campo.safe_y(1));
%             this.Palla.x = 0.2 + rand() * 0.4; % Palla al centro
% 
%             % Reset BotL e PlannerL
%             this.BotL.x = this.Campo.safe_x(1); 
%             this.BotL.y = this.Y_max/2; 
%             this.BotL.theta = 0;
%             this.BotL.err_sum_x = 0; 
%             this.BotL.err_sum_y = 0;
%             this.PlannerL.reset();
% 
%             % Reset BotR (Wanderer) e svuotamento del target
%             this.BotR.x = this.Campo.safe_x(2); 
%             this.BotR.y = this.Y_max/2; 
%             this.BotR.theta = pi;
%             this.BotR.err_sum_x = 0; 
%             this.BotR.err_sum_y = 0;
%             this.BotR.target_x = []; % Fondamentale per evitare crash post-gol
%             this.BotR.target_y = [];
% 
%             % Restituiamo la prima osservazione
%             InitialObservation = this.getObservation();
%         end
% 
%         % --- STEP: Il cuore della logica Semi-MDP ---
%         function [NextObs, Reward, IsDone, LoggedSignals] = step(this, Action)
%             LoggedSignals = [];
% 
%             % 1. Comunichiamo l'azione al Planner
%             switch Action
%                 case 1; this.PlannerL.fsm_state = 1; % PURSUE -> ATTACCO
%                 case 2; this.PlannerL.fsm_state = 2; % BACK
%                 case 3; this.PlannerL.fsm_state = 4; % CUSTOM
%                 case 4; this.PlannerL.fsm_state = 3; % DIFESA
%             end
% 
%             % 2. Ciclo fisico: simuliamo finché la palla non si ferma dopo l'impatto
%             pallaColpita = false;
%             turnStepCounter = 0;
% 
%             while true
%                 turnStepCounter = turnStepCounter + 1;
% 
%                 % Eseguiamo i calcoli per il BotL
%                 [u1_L, u2_L] = this.PlannerL.decide_action(this.BotL, this.BotR, this.Palla, this.Campo, this.X_max, this.Y_max, 0.03);
% 
%                 % --- INIZIO MODIFICHE FASE 1 ---
%                 % [CODICE FASE 1] - Nemico con logica di STOP UNIFICATA
%                 if this.Palla.is_moving()
%                     u1_R = 0; 
%                     u2_R = 0;
%                     this.BotR.err_sum_x = 0; 
%                     this.BotR.err_sum_y = 0;
%                 else
%                     % 1. Definiamo l'area di movimento (la metà campo destra)
%                     area_nemico_x = [this.X_max/2, this.Campo.safe_x(2)];
%                     area_nemico_y = [this.Campo.safe_y(1), this.Campo.safe_y(2)];
%                     % 2. Definiamo l'ostacolo da evitare (il nostro Agente)
%                     ostacoli_nemico = this.BotL;
%                     % 3. Chiamiamo la funzione di movimento casuale
%                     [u1_R, u2_R] = this.BotR.compute_wander_control(area_nemico_x, area_nemico_y, ostacoli_nemico);
%                 end
% 
%                 % Cinematica
%                 this.BotL.linearize_and_move(u1_L, u2_L, this.Ts);
%                 this.BotR.linearize_and_move(u1_R, u2_R, this.Ts); 
% 
%                 % Risoluzione anti-compenetrazione tra i due robot
%                 this.Campo.resolve_bot_bot_collision(this.BotL, this.BotR); 
% 
%                 % Dinamica Palla
%                 this.Campo.apply_repulsion(this.Palla, this.Ts);
%                 this.Palla.update_dynamics(this.Ts);
% 
%                 % Muri
%                 this.Campo.check_bot_walls(this.BotL);
%                 this.Campo.check_bot_walls(this.BotR); 
% 
%                 % Collisioni Palla-Robot
%                 this.Campo.resolve_collision(this.BotL, this.Palla, this.PlannerL.fsm_state);
%                 this.Campo.resolve_collision(this.BotR, this.Palla); % Lascia fare alla fisica base
% 
%                 % --- FINE MODIFICHE FASE 1 ---
% 
%                 % Controllo se la palla ha iniziato a muoversi
%                 if this.Palla.is_moving()
%                     pallaColpita = true;
%                 end
% 
%                 % CONDIZIONI DI USCITA DAL CICLO FISICO
%                 goal = this.Campo.check_ball_walls(this.Palla);
% 
%                 % Caso A: Gol o fine partita
%                 if goal > 0
%                     IsDone = true;
%                     break;
%                 end
% 
%                 % Caso B: La palla è ferma dopo essere stata colpita (Fine turno)
%                 if pallaColpita && ~this.Palla.is_moving()
%                     IsDone = false;
%                     break;
%                 end
% 
%                 % Caso C: Watchdog (Troppo tempo senza colpire la palla)
%                 if turnStepCounter > this.MaxStepsPerTurn && ~pallaColpita
%                     IsDone = true;
%                     break;
%                 end
%             end
% 
%             % 3. Calcolo del Reward e nuova Osservazione
%             Reward = this.calculateReward(goal, turnStepCounter, pallaColpita);
%             NextObs = this.getObservation();
%         end
%     end
% 
%     methods (Access = private)
%         function obs = getObservation(this)
%             % 1. Costanti geometriche per la normalizzazione
%             diag_campo = sqrt(this.X_max^2 + this.Y_max^2);
% 
%             % Vettori posizione (X, Y)
%             pos_L = [this.BotL.x, this.BotL.y];
%             pos_R = [this.BotR.x, this.BotR.y];
%             pos_P = [this.Palla.x, this.Palla.y];
% 
%             % Centri delle porte (BotL attacca verso X_max, difende a 0)
%             porta_avv = [this.X_max, this.Y_max/2];
%             mia_porta = [0, this.Y_max/2];
% 
%             % ==========================================
%             % CALCOLO DELLE 7 FEATURES
%             % ==========================================
% 
%             % Feature 1: Distanza dalla palla (0 -> 1)
%             dist_palla = norm(pos_P - pos_L) / diag_campo;
% 
%             % Feature 2: Angolo relativo verso la palla (-1 -> 1)
%             ang_assoluto_palla = atan2(this.Palla.y - this.BotL.y, this.Palla.x - this.BotL.x);
%             ang_relativo_palla = ang_assoluto_palla - this.BotL.theta;
%             ang_relativo_palla = atan2(sin(ang_relativo_palla), cos(ang_relativo_palla)); 
%             obs_ang_palla = ang_relativo_palla / pi;
% 
%             % Feature 3: Distanza dall'avversario (0 -> 1)
%             dist_avv = norm(pos_R - pos_L) / diag_campo;
% 
%             % Feature 4: Angolo relativo verso l'avversario (-1 -> 1)
%             ang_assoluto_avv = atan2(this.BotR.y - this.BotL.y, this.BotR.x - this.BotL.x);
%             ang_relativo_avv = ang_assoluto_avv - this.BotL.theta;
%             ang_relativo_avv = atan2(sin(ang_relativo_avv), cos(ang_relativo_avv));
%             obs_ang_avv = ang_relativo_avv / pi;
% 
%             % Feature 5: Distanza dalla propria porta (0 -> 1)
%             dist_mia_porta = norm(mia_porta - pos_L) / this.X_max;
% 
%             % Feature 6: Distanza dalla porta avversaria (0 -> 1)
%             dist_porta_avv = norm(porta_avv - pos_L) / this.X_max;
% 
%             % Feature 7: Vantaggio posizionale sulla palla (-1 -> 1)
%             dist_R_palla = norm(pos_P - pos_R);
%             dist_L_palla = norm(pos_P - pos_L);
%             vantaggio = (dist_R_palla - dist_L_palla) / diag_campo;
% 
%             % ==========================================
%             % ASSEMBLAGGIO VETTORE E CLAMPING
%             % ==========================================
%             obs = [dist_palla; obs_ang_palla; dist_avv; obs_ang_avv; dist_mia_porta; dist_porta_avv; vantaggio];
%             obs = max(-1, min(1, obs));
%         end
% 
%         % Helper per il calcolo del Reward
%         function r = calculateReward(this, goal, steps, colpita)
%             if goal == 2 % GOL FATTO (Porta destra per BotL)
%                 r = 10;
%             elseif goal == 1 % GOL SUBITO
%                 r = -10;
%             elseif steps > this.MaxStepsPerTurn && ~colpita
%                 r = -5; % Penalità Watchdog
%             else
%                 r = -0.01; % Piccola penalità temporale per incentivare la velocità
%             end
%         end
% 
%         % Inizializzazione oggetti
%         function setupSimulator(this)
%             A = 0.025; b = 0.03; d = 0.0316;
%             this.Delta = 0.115; this.R_min = 2 * this.Delta;
% 
%             this.Campo = Field([0 0.8], [0 0.6], [d 0.8-d], [d 0.6-d], 0.25, 0.05);
%             this.Palla = Ball(0.4, 0.3, 0.02, 0.0027);
%             this.BotL = Bot(0.05, 0.3, 0, b, d, A, 1.5, 0.5*1.5*A^2, 0.8, 'PID', [4, 0.5]);
%             this.BotR = Bot(0.75, 0.3, pi, b, d, A, 1.5, 0.5*1.5*A^2, 0.8, 'PID', [4, 0.5]);
%             this.PlannerL = Planner(this.Ts, this.R_min, 3*this.Delta, 2*this.Delta, this.Delta, 0.05, 0.3, 1);
%         end
%     end
% end

% %% Fase 0
% classdef RobotBilliardEnv < rl.env.MATLABEnvironment
% 
%     properties
%         % Oggetti del simulatore
%         Palla
%         BotL
%         BotR
%         Campo
%         PlannerL
%         PlannerR
% 
%         % Parametri di simulazione
%         Ts = 0.01
%         X_max = 0.8
%         Y_max = 0.6
% 
%         % Parametri per il calcolo delle soglie (come nel main_test)
%         Delta
%         R_min
% 
%         % Stato interno per il Watchdog
%         MaxStepsPerTurn = 1500 % 15 secondi a Ts=0.01
%     end
% 
%     methods
%         % --- COSTRUTTORE ---
%         function this = RobotBilliardEnv()
%             % 1. Definiamo lo spazio delle osservazioni (7 features)
%             obsInfo = rlNumericSpec([7 1], 'LowerLimit', -1, 'UpperLimit', 1);
%             obsInfo.Name = 'RobotObservations';
% 
%             % 2. Definiamo lo spazio delle azioni (4 macro-azioni)
%             actInfo = rlFiniteSetSpec(1:4);
%             actInfo.Name = 'TacticalActions';
% 
%             % 3. Inizializziamo la classe base
%             this = this@rl.env.MATLABEnvironment(obsInfo, actInfo);
% 
%             % 4. Setup iniziale dei parametri fisici
%             this.setupSimulator();
%         end
% 
%         % --- RESET: Inizio di ogni episodio ---
%         % --- RESET: Inizio di ogni episodio ---
% function [InitialObservation, LoggedSignals] = reset(this)
%     LoggedSignals = [];
% 
%     % Posizionamento randomico della palla (Fase 0: BotL vs Campo Vuoto)
%     this.Palla.vx = 0; this.Palla.vy = 0;
%     this.Palla.y = this.Campo.safe_y(1) + rand() * (this.Campo.safe_y(2) - this.Campo.safe_y(1));
%     this.Palla.x = 0.2 + rand() * 0.4; % Palla al centro
% 
%     % Reset BotL e PlannerL
%     this.BotL.x = this.Campo.safe_x(1); 
%     this.BotL.y = this.Y_max/2; 
%     this.BotL.theta = 0;
%     this.BotL.err_sum_x = 0; 
%     this.BotL.err_sum_y = 0;
%     this.PlannerL.reset();
% 
%     % Aggiunta: Reset BotR (la "statua" torna al suo posto)
%     this.BotR.x = this.Campo.safe_x(2); 
%     this.BotR.y = this.Y_max/2; 
%     this.BotR.theta = pi;
%     this.BotR.err_sum_x = 0; 
%     this.BotR.err_sum_y = 0;
% 
%     % Restituiamo la prima osservazione
%     InitialObservation = this.getObservation();
% end
% 
%         % --- STEP: Il cuore della logica Semi-MDP ---
%         function [NextObs, Reward, IsDone, LoggedSignals] = step(this, Action)
%             LoggedSignals = [];
% 
%             % 1. Comunichiamo l'azione al Planner
%             % Mappatura Strategia 1: Forziamo gli stati della FSM
%             switch Action
%                 case 1; this.PlannerL.fsm_state = 1; % PURSUE -> ATTACCO
%                 case 2; this.PlannerL.fsm_state = 2; % BACK
%                 case 3; this.PlannerL.fsm_state = 4; % CUSTOM
%                 case 4; this.PlannerL.fsm_state = 3; % DIFESA
%             end
% 
%             % 2. Ciclo fisico: simuliamo finché la palla non si ferma dopo l'impatto
%             pallaColpita = false;
%             turnStepCounter = 0;
% 
%             while true
%                 turnStepCounter = turnStepCounter + 1;
% 
%                 % Eseguiamo i calcoli delle classi originali
%                 [u1_L, u2_L] = this.PlannerL.decide_action(this.BotL, this.BotR, this.Palla, this.Campo, this.X_max, this.Y_max, 0.03);
%                 this.BotL.linearize_and_move(u1_L, u2_L, this.Ts);
% 
%                 this.Campo.apply_repulsion(this.Palla, this.Ts);
%                 this.Palla.update_dynamics(this.Ts);
%                 this.Campo.check_bot_walls(this.BotL);
%                 this.Campo.resolve_collision(this.BotL, this.Palla, this.PlannerL.fsm_state);
% 
%                 % Controllo se la palla ha iniziato a muoversi
%                 if this.Palla.is_moving()
%                     pallaColpita = true;
%                 end
% 
%                 % CONDIZIONI DI USCITA DAL CICLO FISICO
%                 goal = this.Campo.check_ball_walls(this.Palla);
% 
%                 % Caso A: Gol o fine partita
%                 if goal > 0
%                     IsDone = true;
%                     break;
%                 end
% 
%                 % Caso B: La palla è ferma dopo essere stata colpita (Fine turno)
%                 if pallaColpita && ~this.Palla.is_moving()
%                     IsDone = false;
%                     break;
%                 end
% 
%                 % Caso C: Watchdog (Troppo tempo senza colpire la palla)
%                 if turnStepCounter > this.MaxStepsPerTurn && ~pallaColpita
%                     IsDone = true;
%                     break;
%                 end
%             end
% 
%             % 3. Calcolo del Reward e nuova Osservazione
%             Reward = this.calculateReward(goal, turnStepCounter, pallaColpita);
%             NextObs = this.getObservation();
%         end
%     end
% 
%     methods (Access = private)
% 
%         function obs = getObservation(this)
%     % 1. Costanti geometriche per la normalizzazione
%     diag_campo = sqrt(this.X_max^2 + this.Y_max^2);
% 
%     % Vettori posizione (X, Y)
%     pos_L = [this.BotL.x, this.BotL.y];
%     pos_R = [this.BotR.x, this.BotR.y];
%     pos_P = [this.Palla.x, this.Palla.y];
% 
%     % Centri delle porte (BotL attacca verso X_max, difende a 0)
%     porta_avv = [this.X_max, this.Y_max/2];
%     mia_porta = [0, this.Y_max/2];
% 
%     % ==========================================
%     % CALCOLO DELLE 7 FEATURES
%     % ==========================================
% 
%     % Feature 1: Distanza dalla palla (0 -> 1)
%     dist_palla = norm(pos_P - pos_L) / diag_campo;
% 
%     % Feature 2: Angolo relativo verso la palla (-1 -> 1)
%     % (0 = palla di fronte, +1/-1 = palla dietro)
%     ang_assoluto_palla = atan2(this.Palla.y - this.BotL.y, this.Palla.x - this.BotL.x);
%     ang_relativo_palla = ang_assoluto_palla - this.BotL.theta;
%     % Funzione per fare il "wrap" dell'angolo tra -pi e +pi
%     ang_relativo_palla = atan2(sin(ang_relativo_palla), cos(ang_relativo_palla)); 
%     obs_ang_palla = ang_relativo_palla / pi;
% 
%     % Feature 3: Distanza dall'avversario (0 -> 1)
%     dist_avv = norm(pos_R - pos_L) / diag_campo;
% 
%     % Feature 4: Angolo relativo verso l'avversario (-1 -> 1)
%     ang_assoluto_avv = atan2(this.BotR.y - this.BotL.y, this.BotR.x - this.BotL.x);
%     ang_relativo_avv = ang_assoluto_avv - this.BotL.theta;
%     ang_relativo_avv = atan2(sin(ang_relativo_avv), cos(ang_relativo_avv));
%     obs_ang_avv = ang_relativo_avv / pi;
% 
%     % Feature 5: Distanza dalla propria porta (0 -> 1)
%     dist_mia_porta = norm(mia_porta - pos_L) / this.X_max;
% 
%     % Feature 6: Distanza dalla porta avversaria (0 -> 1)
%     dist_porta_avv = norm(porta_avv - pos_L) / this.X_max;
% 
%     % Feature 7: Vantaggio posizionale sulla palla (-1 -> 1)
%     % Valori positivi: il nostro BotL è più vicino alla palla del BotR
%     % Valori negativi: l'avversario è in vantaggio
%     dist_R_palla = norm(pos_P - pos_R);
%     dist_L_palla = norm(pos_P - pos_L);
%     vantaggio = (dist_R_palla - dist_L_palla) / diag_campo;
% 
%     % ==========================================
%     % ASSEMBLAGGIO VETTORE E CLAMPING
%     % ==========================================
%     % Il toolbox RL richiede che le osservazioni siano un vettore colonna
%     obs = [dist_palla; obs_ang_palla; dist_avv; obs_ang_avv; dist_mia_porta; dist_porta_avv; vantaggio];
% 
%     % Clamping di sicurezza per evitare sforamenti causati da compenetrazioni o bug fisici
%     obs = max(-1, min(1, obs));
% end
% 
%         % Helper per il calcolo del Reward
%         function r = calculateReward(this, goal, steps, colpita)
%             if goal == 2 % GOL FATTO (Porta destra per BotL)
%                 r = 10;
%             elseif goal == 1 % GOL SUBITO
%                 r = -10;
%             elseif steps > this.MaxStepsPerTurn && ~colpita
%                 r = -5; % Penalità Watchdog
%             else
%                 r = -0.01; % Piccola penalità temporale per incentivare la velocità
%             end
%         end
% 
%         % Inizializzazione oggetti (simile al main_test)
%         function setupSimulator(this)
%             % Parametri bot e palla (estratti dal tuo main)
%             A = 0.025; b = 0.03; d = 0.0316;
%             this.Delta = 0.115; this.R_min = 2 * this.Delta;
% 
%             this.Campo = Field([0 0.8], [0 0.6], [d 0.8-d], [d 0.6-d], 0.25, 0.05);
%             this.Palla = Ball(0.4, 0.3, 0.02, 0.0027);
%             this.BotL = Bot(0.05, 0.3, 0, b, d, A, 1.5, 0.5*1.5*A^2, 0.8, 'PID', [4, 0.5]);
%             this.BotR = Bot(0.75, 0.3, pi, b, d, A, 1.5, 0.5*1.5*A^2, 0.8, 'PID', [4, 0.5]);
%             this.PlannerL = Planner(this.Ts, this.R_min, 3*this.Delta, 2*this.Delta, this.Delta, 0.05, 0.3, 1);
%             this.PlannerR = Planner(this.Ts, this.R_min, 3*this.Delta, 2*this.Delta, this.Delta, 0.75, 0.3, -1);
%         end
%     end
% end
