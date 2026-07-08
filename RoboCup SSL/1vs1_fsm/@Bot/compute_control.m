 %--Controllo Multimodale
        function [u1, u2] = compute_control(obj, target_x_val, target_y_val, Ts)
           
            % 1. Estraggo le coordinate di B (Comune)
            [center, ~] = obj.get_active_circle();
            
            % 2. Calcolo errore attuale (Comune)
            ex = target_x_val - center(1);
            ey = target_y_val - center(2);
            
            % 3. Accumulo integrale e Anti-Windup (Comune)
            obj.err_sum_x = obj.err_sum_x + ex * Ts;
            obj.err_sum_y = obj.err_sum_y + ey * Ts;
            
            limit_int = 0.5; 
            obj.err_sum_x = max(-limit_int, min(limit_int, obj.err_sum_x));
            obj.err_sum_y = max(-limit_int, min(limit_int, obj.err_sum_y));
            
            % 4. STRATEGIA DI CONTROLLO
            switch obj.ctrl_mode
                case 'PID'
                    % Legge PID classica (Disaccoppiata)
                    u1 = obj.Kp * ex + obj.Ki * obj.err_sum_x;
                    u2 = obj.Kp * ey + obj.Ki * obj.err_sum_y;
                    
                case {'H2', 'LQR_INT'}
                    % Legge Ottima MIMO con Effetto Integrale
                    % X_err = [xe_x; xe_y; ep_x; ep_y]
                    X_err = [obj.err_sum_x; obj.err_sum_y; -ex; -ey];
                    U = obj.K_opt * X_err;
                    u1 = U(1); 
                    u2 = U(2);
                    
                case 'LQR_STD'
                    % Esempio di come potresti aggiungere un LQR base
                    % che ignora l'integrale (usa solo l'errore proporzionale)
                    X_err_prop = [-ex; -ey];
                    U = obj.K_opt * X_err_prop;
                    u1 = U(1); 
                    u2 = U(2);
            end
        end
