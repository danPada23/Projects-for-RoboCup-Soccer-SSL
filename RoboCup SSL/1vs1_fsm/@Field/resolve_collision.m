function resolve_collision(obj, bot, ball, fsm_state)
            % Se lo stato non viene passato (retrocompatibilità), assumiamo -1
            if nargin < 4
                fsm_state = -1;
                % Se lo stato FSM non viene fornito, si assume un valore neutro
            end
            
            [B_center, b_rad] = bot.get_active_circle();
            [C_center, c_rad] = bot.get_passive_circle();
            % Estrazione dei due cerchi del robot:
            % attivo = frontale/operativo
            % passivo = corpo centrale
            
            dist_B = norm(B_center - [ball.x; ball.y]);
            dist_C = norm(C_center - [ball.x; ball.y]);
            % Distanze tra palla e rispettivi centri dei cerchi del robot

            v_r_vec = [bot.v * cos(bot.theta); bot.v * sin(bot.theta)];
            % Velocità traslazionale del centro del robot nel riferimento globale
            
            % --- NERF PORTIERE ---
            % Il cerchio ATTIVO entra in gioco SOLO se il robot NON è in stato 3 (DIFESA) ne in STOP 
            if dist_B <= (b_rad + ball.r_p) && fsm_state ~= 3 && fsm_state ~= 7
                r_r = [bot.b * cos(bot.theta); bot.b * sin(bot.theta)]; % Vettore che collega il centro del robot al centro del cerchio attivo
                n_vec = [ball.x; ball.y] - B_center;
                n_hat = n_vec / norm(n_vec);                            % Versore normale di contatto tra cerchio attivo e palla
                
                v_B = [v_r_vec(1) - bot.omega * r_r(2);
                       v_r_vec(2) + bot.omega * r_r(1)];                % Velocità del punto attivo, ottenuta sommando contributo traslazionale e rotazionale
                
                v_rel_n = dot(v_B - [ball.vx; ball.vy], n_hat);         % Componente normale della velocità relativa tra punto attivo e palla
                if v_rel_n > 0
                    cross_rn = r_r(1)*n_hat(2) - r_r(2)*n_hat(1);       % Termine geometrico del momento della forza impulsiva rispetto al centro del robot
                    % Numeratore e denominatore della legge impulsiva d'urto
                    num = (1 + bot.e) * v_rel_n;
                    den = (1/bot.m_r) + (1/ball.m_p) + (cross_rn^2 / bot.I_r);
                    j = num / den;                                      % Intensità dell'impulso scambiato nell'urto
                    % Aggiornamento della velocità della palla dopo l'urto con il cerchio attivo
                    ball.vx = ball.vx + (j / ball.m_p) * n_hat(1);
                    ball.vy = ball.vy + (j / ball.m_p) * n_hat(2);
                end

            elseif dist_C <= (c_rad + ball.r_p)
                % Se il cerchio attivo non interviene, si valuta l'urto con il cerchio passivo
                n_vec = [ball.x; ball.y] - C_center;
                n_hat = n_vec / norm(n_vec); % Versore normale di contatto tra cerchio passivo e palla
                v_rel_n = dot(v_r_vec - [ball.vx; ball.vy], n_hat);  % Componente normale della velocità relativa tra robot e palla
                
                if v_rel_n > 0
                    % Parametri della legge impulsiva semplificata per il corpo passivo
                    num = (1 + bot.e) * v_rel_n;
                    den = (1/bot.m_r) + (1/ball.m_p);
                    j = num / den; % Intensità dell'impulso trasmesso alla palla
                    % Aggiornamento della velocità della palla dopo l'urto con il corpo passivo
                    ball.vx = ball.vx + (j / ball.m_p) * n_hat(1);
                    ball.vy = ball.vy + (j / ball.m_p) * n_hat(2);
                end
            end
        end