classdef Coach < handle
    
    properties
        team_name;          % 'Left' o 'Right'
        reception_radius;   % Il raggio della "bolla" di ricezione/smarcamento
        init_behavior;      % Atteggiamento assegnato al primo calcio d'inizio
        tattica = 3;        % NUOVO: 1=UltraDif, 2=Dif, 3=Eq, 4=Off, 5=UltraOff
        stanchezza = 0;     % Range da 0.0 (freschi) a 1.0 (esausti)
    end
    
    methods
        
        %--Costruttore
        function obj = Coach(team_name, reception_radius, init_behavior)
            obj.team_name = team_name;
            obj.reception_radius = reception_radius;
            obj.init_behavior = init_behavior;
        end
        
        %--Setup Iniziale al Calcio d'Inizio
        function assign_initial_roles(obj, planner_1, planner_2)
            planner_1.reception_radius = obj.reception_radius;
            planner_2.reception_radius = obj.reception_radius;
            
            planner_1.role = 'leader';
            planner_1.follower_state = 'none';
            
            planner_2.role = 'follower';
            planner_2.follower_state = obj.init_behavior;
        end
        
        %--Logica Dinamica: Gestione dei Ruoli e Albero Decisionale Tattico
        function update_roles(obj, bot1, bot2, planner1, planner2, palla, team_enemies, campo, X_max)
            
            % 1. Calcolo distanze attuali dalla palla per il check di vicinanza
            dist1 = norm([bot1.x - palla.x, bot1.y - palla.y]);
            dist2 = norm([bot2.x - palla.x, bot2.y - palla.y]);
            
            % 2. Identificazione dinamica di chi è il Leader attuale
            if strcmp(planner1.role, 'leader')
                leader_planner = planner1;
                follower_planner = planner2;
                dist_leader = dist1;
                dist_follower = dist2;
                leader_bot = bot1;
            else
                leader_planner = planner2;
                follower_planner = planner1;
                dist_leader = dist2;
                dist_follower = dist1;
                leader_bot = bot2;
            end
            
            % Sincronizzazione raggio (per sicurezza se variato a runtime via slider)
            planner1.reception_radius = obj.reception_radius;
            planner2.reception_radius = obj.reception_radius;
            
            % 3. --- IL DOPPIO CHECK PER LO SCAMBIO (CON ISTERESI) ---
            hysteresis_margin = 0.03; 
            
            if (dist_follower < obj.reception_radius) && (dist_follower < (dist_leader - hysteresis_margin))
                
                % Eseguiamo lo scambio logico
                leader_planner.role = 'follower';
                follower_planner.role = 'leader';
                follower_planner.follower_state = 'none';
                
                leader_planner.reset(); 
                follower_planner.reset(); 
                
                % Scambiamo i puntatori locali per passare i dati corretti all'albero
                temp_planner = leader_planner;
                leader_planner = follower_planner;
                follower_planner = temp_planner;
                
                if leader_planner == planner1
                    leader_bot = bot1;
                else
                    leader_bot = bot2;
                end
            end
            
            % 4. --- ESECUZIONE ALBERO DECISIONALE TATTICO ---
            suggested_state = obj.evaluate_tactics(palla, leader_bot, leader_planner, team_enemies, campo, X_max);
            follower_planner.follower_state = suggested_state;
            
        end
        
        %-- Funzione Core dell'Albero Decisionale (Tunable)
        function new_state = evaluate_tactics(obj, palla, leader_bot, leader_planner, team_enemies, campo, X_max)
            
            % A. Calcolo del "Possesso"
            dist_leader_palla = norm([leader_bot.x - palla.x, leader_bot.y - palla.y]);
            
            dist_enemy_palla = inf;
            for i = 1:length(team_enemies)
                d = norm([team_enemies(i).x - palla.x, team_enemies(i).y - palla.y]);
                if d < dist_enemy_palla
                    dist_enemy_palla = d;
                end
            end
            
            we_have_possession = dist_leader_palla < (dist_enemy_palla - 0.02);
            they_have_possession = dist_enemy_palla < (dist_leader_palla - 0.02);
            
            % B. Calcolo Zone di Campo
            if leader_planner.direction == 1
                my_defensive_third = campo.safe_x(1) + (X_max / 3);
                enemy_defensive_third = campo.safe_x(2) - (X_max / 3);
                is_in_my_defense = palla.x < my_defensive_third;
                is_in_enemy_defense = palla.x > enemy_defensive_third;
            else
                my_defensive_third = campo.safe_x(2) - (X_max / 3);
                enemy_defensive_third = campo.safe_x(1) + (X_max / 3);
                is_in_my_defense = palla.x > my_defensive_third;
                is_in_enemy_defense = palla.x < enemy_defensive_third;
            end
            
            % =========================================================
            % C. L'ALBERO DECISIONALE (Identificazione Situazione)
            % =========================================================
            
            if is_in_my_defense && they_have_possession
                ramo = 1; % Situazione Disperata
                
            elseif is_in_enemy_defense && we_have_possession
                ramo = 2; % Attacco Pericoloso
                
            elseif they_have_possession
                ramo = 3; % Transizione Difensiva
                
            elseif we_have_possession && ~is_in_my_defense
                ramo = 4; % Costruzione
                
            else
                ramo = 5; % Contesa / Fallback
            end
            
            % =========================================================
            % D. MATRICE COMPORTAMENTALE (Filtro Tattico)
            % =========================================================
            
            % CORREZIONE: Aggiunti i trattini bassi mancanti agli stati ultra
            switch obj.tattica
                case 1 % ULTRA DIFENSIVO
                    stati = {'ultra defense', 'neutral', 'ultra defense', 'defense', 'defense'};
                    
                case 2 % DIFENSIVO
                    stati = {'ultra defense', 'offense', 'defense', 'defense', 'neutral'};
                    
                case 3 % EQUILIBRATO
                    stati = {'defense', 'offense', 'defense', 'neutral', 'neutral'};
                    
                case 4 % OFFENSIVO
                    stati = {'defense', 'ultra offense', 'neutral', 'offense', 'offense'};
                    
                case 5 % ULTRA OFFENSIVO
                    stati = {'neutral', 'ultra offense', 'offense', 'ultra offense', 'ultra offense'};
            end
            
            % Estraiamo lo stato tattico ideale
            ideal_state = stati{ramo};
            
            % =========================================================
            % E. CALCOLO STANCHEZZA (Probabilità di Errore)
            % =========================================================
            
            % La probabilità di fare la scelta giusta va dal 100% (freschi) al 50% (esausti)
            P_corretta = 1.0 - (0.5 * obj.stanchezza);
            
            % Tiro del dado virtuale
            if rand() <= P_corretta
                % Il robot è lucido e fa la mossa giusta
                new_state = ideal_state;
            else
                % Il robot è confuso: scarta la mossa ideale e ne pesca una a caso tra le 4 rimaste
                all_states = {'ultra_defense', 'defense', 'neutral', 'offense', 'ultra_offense'};
                other_states = all_states(~strcmp(all_states, ideal_state));
                
                indice_casuale = randi(4); % Genera intero da 1 a 4
                new_state = other_states{indice_casuale}; 
            end
            
        end
        
    end
end