clear; 
clc; 
close all;
clear classes;
% ==========================================
% --- PARAMETRI GENERALI E SETUP ---
% ==========================================
X_max = 0.8; Y_max = 0.6; Ts = 0.01;
A = 0.025; b = 0.03; d = A * (sqrt(3)/2)+0.01; 
r_p = 0.02; m_p = 0.0027;

% --- VARIABILI TEMPO E MATCH ---
durata_tempo = 5*6; % 10 minuti in secondi (600) per ogni tempo
tempo_simulato = 0;
tempo_corrente = 1; % 1 = Primo tempo, 2 = Secondo tempo

% --- PARAMETRI ROBOT ---
m_r = 1.5; I_r = 0.5 * m_r * A^2; 
e = 0.8; % [cite: 2026-01-28]

% --- SCELTA CONTROLLO ---
% Uso un cell array ({}) per gestire stringhe di lunghezza diversa in MATLAB
control_set = {'PID', 'H2'}; 
control_mode = control_set{2}; 

switch control_mode
    case 'PID'
        gains = [4.0, 0.5]; % [Kp, Ki]
        
    case 'H2'
        % --- Matrici del Plant (Doppio Integratore) ---
        A_p = zeros(2, 2);
        B_p = eye(2);
        C_r = eye(2); % Misuriamo la posizione [xb, yb]
        D_r = zeros(2, 2);
        B_w = zeros(2, 2); 
        F_r = zeros(2, 2); 
        
        % --- Costruzione Sistema Aumentato (4 stati: 2 integrali, 2 proporzionali) ---
        A_aug = [zeros(2, 2), -C_r; 
                 zeros(2, 2),  A_p];
             
        % B_aug è la "B2" (Ingressi di controllo u)
        B_aug = [-D_r; 
                  B_p];
              
        % Bw_aug è la "B1" (Ingressi esogeni: disturbi e riferimento)
        Bw_aug = [-F_r, eye(2); 
                   B_w, zeros(2, 2)];
               
        % --- Pesi Obiettivo Z ---
        W_xe = (1/0.1) * eye(2); % Peso sull'errore integrale
        W_u  = (1/0.3) * eye(2); % Peso sull'uso degli attuatori
        
        % Cz_aug è la "C2" (Mappa lo stato [xe; xp] sull'uscita Z)
        Cz_aug = [W_xe, zeros(2, 2); 
                  zeros(2, 4)];
              
        % Dz_aug è la "D22" (Mappa l'ingresso u sull'uscita Z)
        Dz_aug = [zeros(2, 2); 
                  W_u];
              
        % --- Sintesi H2 ---
        K_opt = H2_compute(A_aug, B_aug, Bw_aug, Cz_aug, Dz_aug); 
        
        % Assegno la matrice di guadagno al payload flessibile
        gains = K_opt;
end
       

% --- SETUP SOGLIE FSM E DISTANZE ---
N_pallini = 3.5; step_pallini = 0.05;
dist_base = Y_max/2;     
Delta = dist_base - b - d - (N_pallini * step_pallini);

R_min = 2 * Delta;
R_max = R_min + (2 * Delta); 
R_mid = (R_max + R_min) / 2; 

goal_width = 0.25; goal_depth = r_p + 0.03; % Aumentata di 2.5 cm per lato

% --- VARIABILI PUNTEGGIO ---
score_L = 0; % Punteggio Bot Sinistro (Ciano)
score_R = 0; % Punteggio Bot Destro (Arancio)

stati_nomi = {'WAIT', 'PURSUE', 'BACK', 'DIFESA', 'CUSTOM', 'ACTION', 'ATTACCO', 'STOP', 'ESCAPE', 'SPAZZATA'};

% ==========================================
% --- INIZIALIZZAZIONE AMBIENTE E CAMPO ---
% ==========================================
lim_x = [0, X_max]; lim_y = [0, Y_max];
safe_x = [d, X_max - d]; safe_y = [d, Y_max - d];
campo = Field(lim_x, lim_y, safe_x, safe_y, goal_width, goal_depth);

% ==========================================
% --- SPAWN INIZIALE RANDOMIZZATO ---
% ==========================================
bot_L_start_x = campo.safe_x(1);
bot_R_start_x = campo.safe_x(2);
start_y = Y_max / 2;

% Asse Y casuale ma sicuro per evitare compenetrazioni coi muri
ball_start_y = campo.safe_y(1) + rand() * (campo.safe_y(2) - campo.safe_y(1));

% Il caso decide in quale metà campo spawnerà la palla (50% probabilità)
if rand() > 0.5
    % Metà campo Sinistra
    min_x = bot_L_start_x + R_mid;
    max_x = (X_max / 2) - 0.05; % Lascia un piccolo margine dal centrocampo
    ball_start_x = min_x + rand() * (max_x - min_x);
    disp('Calcio d''inizio: Palla nella metà campo SINISTRA');
else
    % Metà campo Destra
    min_x = (X_max / 2) + 0.05;
    max_x = bot_R_start_x - R_mid;
    ball_start_x = min_x + rand() * (max_x - min_x);
    disp('Calcio d''inizio: Palla nella metà campo DESTRA');
end

% Creazione Oggetti Fisici
palla = Ball(ball_start_x, ball_start_y, r_p, m_p);
bot_left  = Bot(bot_L_start_x, start_y, 0,  b, d, A, m_r, I_r, e, control_mode, gains); 

gains_wander = [4.0, 0.5]; 
bot_right = Bot(bot_R_start_x, start_y, pi, b, d, A, m_r, I_r, e, 'PID', gains_wander); 

% Creazione Cervelli
planner_left  = Planner(Ts, R_min, R_max, R_mid, Delta, bot_left.x, bot_left.y, 1);

% ==========================================
% --- SETUP GRAFICA ---
% ==========================================
Scenario = figure('Name','Billiard Robot Simulator - 1vs1 Match', 'NumberTitle','off', 'Position', [100, 100, 800, 600]);
hold on; axis equal;
margine_camera = 0.08;
xlim([lim_x(1) - margine_camera, lim_x(2) + margine_camera]); 
ylim([lim_y(1) - margine_camera, lim_y(2) + margine_camera]);
disp('--- INIZIO PARTITA 1vs1 ---');

th_circ = linspace(0, 2*pi, 100);
circ_unit_x = cos(th_circ);
circ_unit_y = sin(th_circ);

% ==========================================
% --- LOOP PRINCIPALE ---
% ==========================================
while ishandle(Scenario)

    tempo_simulato = tempo_simulato + Ts;
    
    % 1. I CERVELLI DECIDONO IN CONTEMPORANEA
    [u1_L, u2_L] = planner_left.decide_action(bot_left, bot_right, palla, campo, X_max, Y_max, d);
    
    % --- NUOVO CERVELLO BOT DESTRO (WANDERER CON STOP UNIFICATO) ---
    if palla.is_moving()
        % Se la palla si muove, il bot frena (u1=0, u2=0) e non calcola nuovi target
        u1_R = 0; 
        u2_R = 0;
        
        % Azzero l'integrale per evitare accumuli durante la frenata 
        bot_right.err_sum_x = 0; 
        bot_right.err_sum_y = 0;
    else
        % Se la palla è ferma, si muove casualmente
        area_nemico_x = [X_max/2, campo.safe_x(2)];
        area_nemico_y = [campo.safe_y(1), campo.safe_y(2)];
        ostacoli_nemico = bot_left;
        [u1_R, u2_R] = bot_right.compute_wander_control(area_nemico_x, area_nemico_y, ostacoli_nemico);
    end
    
    % 2. CINEMATICA E FISICA 
    bot_left.linearize_and_move(u1_L, u2_L, Ts);
    bot_right.linearize_and_move(u1_R, u2_R, Ts);
    
    % --- NUOVO: Risoluzione anti-compenetrazione tra i robot ---
    campo.resolve_bot_bot_collision(bot_left, bot_right);
   
    campo.apply_repulsion(palla, Ts);
    palla.update_dynamics(Ts);
    
    % Il controllo muri viene DOPO la separazione dei bot, 
    % così se la separazione li spinge fuori dal campo, i muri li rimettono dentro.
    campo.check_bot_walls(bot_left);
    campo.check_bot_walls(bot_right);
    
    % Entrambi i bot possono urtare la palla 
    campo.resolve_collision(bot_left, palla, planner_left.fsm_state);
    campo.resolve_collision(bot_right, palla);

    goal_status = campo.check_ball_walls(palla);
    
    % 3. GESTIONE EVENTI (Gol e Aggiornamento Punteggio)
    if goal_status > 0
        drawnow; pause(1.0); 
        
        % Assegnazione Punti
        if goal_status == 1
            score_R = score_R + 1;
            fprintf('\n!!! GOL DEL BOT DESTRO !!!\n');
        elseif goal_status == 2
            score_L = score_L + 1;
            fprintf('\n!!! GOL DEL BOT SINISTRO !!!\n');
        end
        fprintf('--- PUNTEGGIO ATTUALE: Sinistra %d  |  Destra %d ---\n\n', score_L, score_R);
        
        % Reset Posizioni Bot 
        bot_left.x = campo.safe_x(1); bot_left.y = Y_max / 2; bot_left.theta = 0;
        bot_left.v = 0; bot_left.omega = 0; bot_left.err_sum_x = 0; bot_left.err_sum_y = 0;
        
        bot_right.x = campo.safe_x(2); bot_right.y = Y_max / 2; bot_right.theta = pi;
        bot_right.v = 0; bot_right.omega = 0; bot_right.err_sum_x = 0; bot_right.err_sum_y = 0;
        bot_right.target_x = []; bot_right.target_y = [];
        
        % --- RESPAWN RANDOM POST-GOL ---
        % Asse Y casuale per lo spawn
        palla.y = campo.safe_y(1) + rand() * (campo.safe_y(2) - campo.safe_y(1));
        
        % Vantaggio palla a chi ha subito gol (nella sua metà campo)
        if goal_status == 1
            min_x = bot_left.x + R_mid;
            max_x = (X_max / 2) - 0.05;
            palla.x = min_x + rand() * (max_x - min_x);
        elseif goal_status == 2
            min_x = (X_max / 2) + 0.05;
            max_x = bot_right.x - R_mid;
            palla.x = min_x + rand() * (max_x - min_x);
        end
        
        palla.vx = 0; palla.vy = 0; palla.theta = 0; 
        
        % Reset manuale e blindato dei Planner
        planner_left.fsm_state = 0; planner_left.prev_state = -1;
        planner_left.calcolo_effettuato = false; planner_left.P_A = []; planner_left.P_Beyond = [];
        
        pause(0.5); 
    end
    
    % 4. DISEGNO GRAFICO
    % ==========================================
    cla;
    campo.draw();
    
   % Calcolo minuti e secondi per il tabellone a schermo
    minuti = floor(tempo_simulato / 60);
    secondi = floor(mod(tempo_simulato, 60));
    
    % Titolo aggiornato con Cronometro e Tempo Corrente
    title(sprintf('Partita 1vs1 | Tempo %d - %02d:%02d | Punteggio: Lazzie %d - %d Amaggica', ...
        tempo_corrente, minuti, secondi, score_L, score_R), 'FontSize', 14, 'FontWeight', 'bold');
    
    % --- R_MIN E CERCHI BOT SINISTRO (CIANO) ---
    bot_left.draw('inter');      
    text(bot_left.x, bot_left.y + 0.05, stati_nomi{planner_left.fsm_state + 1}, 'Color', [0 0.5 0.5], 'FontWeight', 'bold', 'HorizontalAlignment', 'center');
    
    % % Linea dinamica R_min
    % x_soglia_L = bot_left.x + R_min;
    % plot([x_soglia_L, x_soglia_L], [0, Y_max], '-.','Color',[0 0.5 0.5], 'LineWidth', 1.5);
    
    % Disegno Cerchi Dinamici
    [C_center_L, C_rad_L] = bot_left.get_passive_circle();
    [B_center_L, B_rad_L] = bot_left.get_active_circle();
    
    plot(C_center_L(1) + C_rad_L*circ_unit_x, C_center_L(2) + C_rad_L*circ_unit_y, '--','Color' ,[0 0.5 0.5],'LineWidth', 1.5); % Cerchio passivo sempre visibile
    if planner_left.fsm_state ~= 3 % Se NON è in difesa, mostra anche il cerchio attivo
        plot(B_center_L(1) + B_rad_L*circ_unit_x, B_center_L(2) + B_rad_L*circ_unit_y, '--','Color',[0 0.5 0.5], 'LineWidth', 1.5);
    end

    % Target FSM Bot Sinistro
    if planner_left.fsm_state == 8
        plot(planner_left.target_x, planner_left.target_y, 'cs', 'MarkerSize', 8, 'MarkerFaceColor', 'c');
    elseif planner_left.fsm_state ~= 0 && planner_left.fsm_state ~= 6
        plot(planner_left.target_x, planner_left.target_y, 'cx', 'MarkerSize', 8, 'LineWidth', 1.5);
    end
    if planner_left.fsm_state == 6 && ~isempty(planner_left.P_A)
        plot(planner_left.P_A(1), planner_left.P_A(2), 'co', 'MarkerSize', 6, 'MarkerFaceColor', 'c');
    end

    % --- R_MIN E CERCHI BOT DESTRO (ARANCIO) ---
    bot_right.draw('milan');      
    text(bot_right.x, bot_right.y + 0.05, 'WANDER', 'Color', [1 0.5 0], 'FontWeight', 'bold', 'HorizontalAlignment', 'center');
    
    % % Linea dinamica R_min
    % x_soglia_R = bot_right.x - R_min;
    % plot([x_soglia_R, x_soglia_R], [0, Y_max], 'Color', [1 0.5 0], 'LineStyle', '-.', 'LineWidth', 1.5);
    
    % Disegno Cerchi Dinamici
    [C_center_R, C_rad_R] = bot_right.get_passive_circle();
    [B_center_R, B_rad_R] = bot_right.get_active_circle();
    
    plot(C_center_R(1) + C_rad_R*circ_unit_x, C_center_R(2) + C_rad_R*circ_unit_y, 'Color', [1 0.5 0], 'LineStyle', '--', 'LineWidth', 1.5);
    plot(B_center_R(1) + B_rad_R*circ_unit_x, B_center_R(2) + B_rad_R*circ_unit_y, 'Color', [1 0.5 0], 'LineStyle', '--', 'LineWidth', 1.5);
    
    if ~isempty(bot_right.target_x)
        plot(bot_right.target_x, bot_right.target_y, 'rx', 'MarkerSize', 8, 'LineWidth', 1.5);
    end

    palla.draw(Delta, false);
    drawnow;

    % ==========================================
    % 5. GESTIONE CRONOMETRO E TEMPI (L'Arbitro)
    % ==========================================
    if tempo_simulato >= durata_tempo
        if tempo_corrente == 1
            % FINE PRIMO TEMPO
            disp(' ');
            disp('=========================================');
            disp('      TRIPLICE FISCHIO - FINE 1° TEMPO   ');
            fprintf('      PUNTEGGIO PARZIALE: Ciano %d - %d Arancio\n', score_L, score_R);
            disp('=========================================');
            pause(3); % Pausa per far leggere lo schermo all'utente
            
            % Setup Secondo Tempo
            tempo_corrente = 2;
            tempo_simulato = 0;
            
            % Reset posizioni simmetrico (Palla al centro per il nuovo calcio d'inizio)
            bot_left.x = campo.safe_x(1); bot_left.y = Y_max / 2; bot_left.theta = 0;
            bot_left.v = 0; bot_left.omega = 0; bot_left.err_sum_x = 0; bot_left.err_sum_y = 0;
            
            bot_right.x = campo.safe_x(2); bot_right.y = Y_max / 2; bot_right.theta = pi;
            bot_right.v = 0; bot_right.omega = 0; bot_right.err_sum_x = 0; bot_right.err_sum_y = 0;
            bot_right.target_x = []; bot_right.target_y = [];
            
            palla.x = X_max / 2; palla.y = Y_max / 2;
            palla.vx = 0; palla.vy = 0; palla.theta = 0;
            
            planner_left.reset();
            disp('--- INIZIO SECONDO TEMPO ---');
            
        elseif tempo_corrente == 2
            % FINE PARTITA
            disp(' ');
            disp('=========================================');
            disp('      TRIPLICE FISCHIO - FINE PARTITA!   ');
            fprintf('      RISULTATO FINALE: Ciano %d - %d Arancio\n', score_L, score_R);
            if score_L > score_R
                disp('      VINCITORE: BOT SINISTRO (CIANO)    ');
            elseif score_R > score_L
                disp('      VINCITORE: BOT DESTRO (ARANCIO)    ');
            else
                disp('      PAREGGIO!                          ');
            end
            disp('=========================================');
            pause(5); % Pausa lunga per celebrare il risultato
            
            % Reset totale per un nuovo match infinito
            tempo_corrente = 1;
            tempo_simulato = 0;
            score_L = 0;
            score_R = 0;
            
            bot_left.x = campo.safe_x(1); bot_left.y = Y_max / 2; bot_left.theta = 0;
            bot_left.v = 0; bot_left.omega = 0; bot_left.err_sum_x = 0; bot_left.err_sum_y = 0;
            
            bot_right.x = campo.safe_x(2); bot_right.y = Y_max / 2; bot_right.theta = pi;
            bot_right.v = 0; bot_right.omega = 0; bot_right.err_sum_x = 0; bot_right.err_sum_y = 0;
            bot_right.target_x = []; bot_right.target_y = [];
            
            palla.x = X_max / 2; palla.y = Y_max / 2;
            palla.vx = 0; palla.vy = 0; palla.theta = 0;
            
            planner_left.reset();
            disp('--- INIZIO NUOVA PARTITA ---');
        end
    end






    pause(Ts);

end
