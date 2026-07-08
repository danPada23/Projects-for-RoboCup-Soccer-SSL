clear; clc; close all;
% =========================================================================
% --- 1. IMPOSTAZIONI ---
% =========================================================================
N_campionati = 10;
N_partite_per_scontro = 2; % Andata e Ritorno
nomi_partecipanti = {'FSM','Standard','Continuo','Discreto','Striker','Zeman','Defender','Simeone','Catenaccio_Totale'};
num_partecipanti = length(nomi_partecipanti);

% Pre-allocazione Database Master
num_matchups = (num_partecipanti * (num_partecipanti - 1)) / 2;
tot_partite_assolute = N_campionati * num_matchups * N_partite_per_scontro;
log_Camp = zeros(tot_partite_assolute, 1);
log_SqL = cell(tot_partite_assolute, 1);
log_SqR = cell(tot_partite_assolute, 1);
log_GolL = zeros(tot_partite_assolute, 1);
log_GolR = zeros(tot_partite_assolute, 1);

% --- NUOVO: Pre-allocazione Database Moviola ---
log_AG_Veri_L = zeros(tot_partite_assolute, 1);
log_AG_Rimpalli_L = zeros(tot_partite_assolute, 1);
log_AG_Veri_R = zeros(tot_partite_assolute, 1);
log_AG_Rimpalli_R = zeros(tot_partite_assolute, 1);

% --- CARICAMENTO CERVELLI ---
fprintf('--- CARICAMENTO CERVELLI IN RAM ---\n');
cervelli = cell(1, num_partecipanti);
for i = 1:num_partecipanti
    if strcmp(nomi_partecipanti{i}, 'FSM')
        cervelli{i} = 'FSM';
    else
        data = load(sprintf('Agente_%s.mat', nomi_partecipanti{i}));
        cervelli{i} = data.agent;
    end
end
fprintf('Setup completato. Partite totali previste: %d\n\n', tot_partite_assolute);

% =========================================================================
% --- 2. AVVIO CAMPIONATI IBRIDI (LIVE + LOGGING) ---
% =========================================================================
counter_partita = 1;
for camp = 1:N_campionati
    fprintf('\n======================================================\n');
    fprintf('        INIZIO CAMPIONATO STAGIONE %d                 \n', camp);
    fprintf('======================================================\n');
    
    % Inizializza statistiche della singola stagione
    pti_stag = zeros(num_partecipanti, 1);
    v_stag = zeros(num_partecipanti, 1);
    p_stag = zeros(num_partecipanti, 1);
    s_stag = zeros(num_partecipanti, 1);
    gf_stag = zeros(num_partecipanti, 1);
    gs_stag = zeros(num_partecipanti, 1);
    
    % --- NUOVO: Contatori Stagionali Moviola ---
    ag_veri_stag = zeros(num_partecipanti, 1);     % Autogol Kamikaze
    ag_rimpalli_stag = zeros(num_partecipanti, 1); % Deviazioni sfortunate
    
    for i = 1:num_partecipanti
        for j = i+1:num_partecipanti
            for k = 1:N_partite_per_scontro
                if mod(k, 2) ~= 0, idx_L = i; idx_R = j;
                else,              idx_L = j; idx_R = i; end
                
                % Lancia simulazione e raccogli la Moviola in campo
                [g_L, g_R, ag_v_L, ag_r_L, ag_v_R, ag_r_R] = run_headless_match(cervelli{idx_L}, cervelli{idx_R});
                
                tot_ag_L = ag_v_L + ag_r_L;
                tot_ag_R = ag_v_R + ag_r_R;
                
                % --- STAMPA LIVE DELLA PARTITA ---
                msg_autogol = '';
                if tot_ag_L > 0 || tot_ag_R > 0
                    msg_autogol = ' (Moviola:';
                    if tot_ag_L > 0
                        msg_autogol = [msg_autogol sprintf(' %s [%d Kamikaze, %d Rimpalli]', nomi_partecipanti{idx_L}, ag_v_L, ag_r_L)];
                    end
                    if tot_ag_R > 0
                        msg_autogol = [msg_autogol sprintf(' %s [%d Kamikaze, %d Rimpalli]', nomi_partecipanti{idx_R}, ag_v_R, ag_r_R)];
                    end
                    msg_autogol = [msg_autogol ')'];
                end
                
                if g_L > g_R
                    fprintf('Match: %-15s %d - %d %-15s -> Vince %s%s\n', nomi_partecipanti{idx_L}, g_L, g_R, nomi_partecipanti{idx_R}, nomi_partecipanti{idx_L}, msg_autogol);
                    pti_stag(idx_L) = pti_stag(idx_L) + 3; v_stag(idx_L) = v_stag(idx_L) + 1; s_stag(idx_R) = s_stag(idx_R) + 1;
                elseif g_R > g_L
                    fprintf('Match: %-15s %d - %d %-15s -> Vince %s%s\n', nomi_partecipanti{idx_L}, g_L, g_R, nomi_partecipanti{idx_R}, nomi_partecipanti{idx_R}, msg_autogol);
                    pti_stag(idx_R) = pti_stag(idx_R) + 3; v_stag(idx_R) = v_stag(idx_R) + 1; s_stag(idx_L) = s_stag(idx_L) + 1;
                else
                    fprintf('Match: %-15s %d - %d %-15s -> Pareggio%s\n', nomi_partecipanti{idx_L}, g_L, g_R, nomi_partecipanti{idx_R}, msg_autogol);
                    pti_stag(idx_L) = pti_stag(idx_L) + 1; pti_stag(idx_R) = pti_stag(idx_R) + 1;
                    p_stag(idx_L) = p_stag(idx_L) + 1; p_stag(idx_R) = p_stag(idx_R) + 1;
                end
                
                % Aggiorna Gol Stagionali
                gf_stag(idx_L) = gf_stag(idx_L) + g_L; gs_stag(idx_L) = gs_stag(idx_L) + g_R;
                gf_stag(idx_R) = gf_stag(idx_R) + g_R; gs_stag(idx_R) = gs_stag(idx_R) + g_L;
                
                % Aggiorna Moviola Stagionale
                ag_veri_stag(idx_L) = ag_veri_stag(idx_L) + ag_v_L;
                ag_rimpalli_stag(idx_L) = ag_rimpalli_stag(idx_L) + ag_r_L;
                ag_veri_stag(idx_R) = ag_veri_stag(idx_R) + ag_v_R;
                ag_rimpalli_stag(idx_R) = ag_rimpalli_stag(idx_R) + ag_r_R;
                
                % --- LOG NEL DATABASE MASTER ---
                log_Camp(counter_partita) = camp;
                log_SqL{counter_partita} = nomi_partecipanti{idx_L}; log_SqR{counter_partita} = nomi_partecipanti{idx_R};
                log_GolL(counter_partita) = g_L; log_GolR(counter_partita) = g_R;
                
                log_AG_Veri_L(counter_partita) = ag_v_L;
                log_AG_Rimpalli_L(counter_partita) = ag_r_L;
                log_AG_Veri_R(counter_partita) = ag_v_R;
                log_AG_Rimpalli_R(counter_partita) = ag_r_R;
                counter_partita = counter_partita + 1;
            end
        end
    end
    
    % --- STAMPA CLASSIFICA FINE STAGIONE ---
    DR_stag = gf_stag - gs_stag;
    Tot_Autogol = ag_veri_stag + ag_rimpalli_stag;
    
    ClassificaStagione = table(nomi_partecipanti', pti_stag, v_stag, p_stag, s_stag, gf_stag, gs_stag, DR_stag, Tot_Autogol, ag_veri_stag, ag_rimpalli_stag, ...
        'VariableNames', {'Squadra', 'Punti', 'V', 'P', 'S', 'GF', 'GS', 'DR', 'AutogolTot', 'AG_Kamikaze', 'AG_Rimpallo'});
    ClassificaStagione = sortrows(ClassificaStagione, {'Punti', 'DR'}, {'descend', 'descend'});
    
    fprintf('\n--- CLASSIFICA FINALE STAGIONE %d ---\n', camp);
    disp(ClassificaStagione);
    pause(1); % Piccola pausa per leggere i risultati
end

% Salvataggio Database Globale
MatchHistory = table(log_Camp, log_SqL, log_SqR, log_GolL, log_GolR, log_AG_Veri_L, log_AG_Rimpalli_L, log_AG_Veri_R, log_AG_Rimpalli_R, ...
    'VariableNames', {'Campionato', 'SquadraL', 'SquadraR', 'GolL', 'GolR', 'AG_Veri_L', 'AG_Rimpalli_L', 'AG_Veri_R', 'AG_Rimpalli_R'});
save('MatchHistory_DB.mat', 'MatchHistory');
disp('Simulazione Conclusa. Database Globale salvato con successo!');





% clear; clc; close all;
% 
% % =========================================================================
% % --- PARTE 1: IMPOSTAZIONI E SIMULAZIONE MASSIVA ---
% % =========================================================================
% N_campionati = 2;
% N_partite_per_scontro = 10; % Moltiplicato per 10 campionati = 40 sfide per ogni coppia
% 
% nomi_partecipanti = {'Standard', 'Continuo', 'Simeone', 'Zeman','Discreto'};
% num_partecipanti = length(nomi_partecipanti);
% 
% % Pre-allocazione per la massima velocità (evita che MATLAB rallenti)
% num_matchups = (num_partecipanti * (num_partecipanti - 1)) / 2;
% tot_partite_assolute = N_campionati * num_matchups * N_partite_per_scontro;
% 
% log_Camp = zeros(tot_partite_assolute, 1);
% log_SqL = cell(tot_partite_assolute, 1);
% log_SqR = cell(tot_partite_assolute, 1);
% log_GolL = zeros(tot_partite_assolute, 1);
% log_GolR = zeros(tot_partite_assolute, 1);
% 
% % --- CARICAMENTO CERVELLI ---
% fprintf('--- CARICAMENTO CERVELLI IN RAM ---\n');
% cervelli = cell(1, num_partecipanti);
% for i = 1:num_partecipanti
%     if strcmp(nomi_partecipanti{i}, 'FSM')
%         cervelli{i} = 'FSM';
%     else
%         data = load(sprintf('Agente_%s.mat', nomi_partecipanti{i}));
%         cervelli{i} = data.agent;
%     end
% end
% 
% % --- AVVIO DEI CAMPIONATI ---
% fprintf('\n--- INIZIO DI %d CAMPIONATI HEADLESS ---\n', N_campionati);
% tic;
% counter_partita = 1;
% 
% for camp = 1:N_campionati
%     fprintf('>> Avvio Campionato %d/%d...\n', camp, N_campionati);
% 
%     for i = 1:num_partecipanti
%         for j = i+1:num_partecipanti
%             for k = 1:N_partite_per_scontro
%                 % Alternanza Casa/Trasferta
%                 if mod(k, 2) ~= 0, idx_L = i; idx_R = j;
%                 else,              idx_L = j; idx_R = i; end
% 
%                 % Esegui match silente
%                 [g_L, g_R] = run_headless_match(cervelli{idx_L}, cervelli{idx_R});
% 
%                 % Log nel Database
%                 log_Camp(counter_partita) = camp;
%                 log_SqL{counter_partita} = nomi_partecipanti{idx_L};
%                 log_SqR{counter_partita} = nomi_partecipanti{idx_R};
%                 log_GolL(counter_partita) = g_L;
%                 log_GolR(counter_partita) = g_R;
% 
%                 counter_partita = counter_partita + 1;
%             end
%         end
%     end
% end
% tempo_tot = toc;
% fprintf('Simulazione completata in %.1f secondi! Partite totali giocate: %d\n', tempo_tot, tot_partite_assolute);
% 
% % Creazione e salvataggio del Database Master
% MatchHistory = table(log_Camp, log_SqL, log_SqR, log_GolL, log_GolR, ...
%     'VariableNames', {'Campionato', 'SquadraL', 'SquadraR', 'GolL', 'GolR'});
% save('MatchHistory_DB.mat', 'MatchHistory');
% disp('Database salvato in MatchHistory_DB.mat');
% 
% % =========================================================================
% % --- PARTE 2: ANALISI AVANZATA DELLO STORICO (IL TALENT SCOUT) ---
% % =========================================================================
% % Scegli qui chi vuoi mettere sotto la lente d'ingrandimento
% agente_target = 'Zeman'; 
% 
% fprintf('\n======================================================\n');
% fprintf('    REPORT DETTAGLIATO AGENTE: %s\n', upper(agente_target));
% fprintf('======================================================\n');
% 
% % Estraiamo solo le partite in cui ha giocato il target (a sx o a dx)
% idx_giocate = strcmp(MatchHistory.SquadraL, agente_target) | strcmp(MatchHistory.SquadraR, agente_target);
% PartiteTarget = MatchHistory(idx_giocate, :);
% 
% tot_giocate = height(PartiteTarget);
% vittorie_tot = 0; pareggi_tot = 0; sconfitte_tot = 0;
% gol_fatti_tot = 0; gol_subiti_tot = 0;
% 
% % Statistiche contro ogni specifico avversario
% avversari = setdiff(nomi_partecipanti, agente_target);
% stat_avv = zeros(length(avversari), 5); % [Vittorie, Pareggi, Sconfitte, GF, GS]
% 
% for p = 1:tot_giocate
%     % Standardizziamo la visuale: Il target è "Mio", l'altro è "Avv"
%     if strcmp(PartiteTarget.SquadraL{p}, agente_target)
%         avv = PartiteTarget.SquadraR{p};
%         gol_mio = PartiteTarget.GolL(p);
%         gol_avv = PartiteTarget.GolR(p);
%     else
%         avv = PartiteTarget.SquadraL{p};
%         gol_mio = PartiteTarget.GolR(p);
%         gol_avv = PartiteTarget.GolL(p);
%     end
% 
%     % Aggiorna Totali
%     gol_fatti_tot = gol_fatti_tot + gol_mio;
%     gol_subiti_tot = gol_subiti_tot + gol_avv;
% 
%     idx_avv = find(strcmp(avversari, avv));
%     stat_avv(idx_avv, 4) = stat_avv(idx_avv, 4) + gol_mio;
%     stat_avv(idx_avv, 5) = stat_avv(idx_avv, 5) + gol_avv;
% 
%     if gol_mio > gol_avv
%         vittorie_tot = vittorie_tot + 1;
%         stat_avv(idx_avv, 1) = stat_avv(idx_avv, 1) + 1;
%     elseif gol_mio < gol_avv
%         sconfitte_tot = sconfitte_tot + 1;
%         stat_avv(idx_avv, 3) = stat_avv(idx_avv, 3) + 1;
%     else
%         pareggi_tot = pareggi_tot + 1;
%         stat_avv(idx_avv, 2) = stat_avv(idx_avv, 2) + 1;
%     end
% end
% 
% % --- STAMPA RISULTATI ---
% win_rate = (vittorie_tot / tot_giocate) * 100;
% fprintf('Partite Giocate: %d \n', tot_giocate);
% fprintf('Record Assoluto: %d V - %d P - %d S  (Win Rate: %.1f%%)\n', vittorie_tot, pareggi_tot, sconfitte_tot, win_rate);
% fprintf('Gol Fatti: %d  |  Gol Subiti: %d  |  Differenza Reti: %+d\n\n', gol_fatti_tot, gol_subiti_tot, gol_fatti_tot - gol_subiti_tot);
% 
% fprintf('--- STATISTICHE HEAD-TO-HEAD ---\n');
% DiffRetiAvv = stat_avv(:,4) - stat_avv(:,5);
% T_Avv = table(avversari', stat_avv(:,1), stat_avv(:,2), stat_avv(:,3), stat_avv(:,4), stat_avv(:,5), DiffRetiAvv, ...
%     'VariableNames', {'Avversario', 'V', 'P', 'S', 'GF', 'GS', 'DR'});
% disp(T_Avv);
% 
% % Calcolo Bestia Nera e Vittima (basato sulla differenza reti H2H)
% [~, idx_bestia] = min(DiffRetiAvv);
% [~, idx_vittima] = max(DiffRetiAvv);
% 
% fprintf('------------------------------------------------------\n');
% fprintf('VITTIMA PREFERITA: %s (Differenza reti: %+d)\n', avversari{idx_vittima}, DiffRetiAvv(idx_vittima));
% fprintf('LA BESTIA NERA   : %s (Differenza reti: %+d)\n', avversari{idx_bestia}, DiffRetiAvv(idx_bestia));
% fprintf('======================================================\n');



% clear; clc; close all;
% 
% % ==========================================
% % 1. IMPOSTAZIONI DEL TORNEO
% % ==========================================
% % Quante partite giocano tra di loro due squadre? (Es. 10 partite)
% % Consiglio: usa un numero PARI, così giocheranno esattamente 
% % metà volte a sinistra e metà a destra.
% N_partite_per_scontro = 10; 
% 
% % Definisci la "Rosa" dei partecipanti (I nomi devono corrispondere 
% % esattamente ai file salvati, escludendo 'Agente_' e '.mat')
% % La stringa 'FSM' è speciale e invoca la tua Macchina a Stati.
% nomi_partecipanti = {'Standard', 'Continuo', 'Simeone', 'Zeman', 'Discreto'};
% 
% num_partecipanti = length(nomi_partecipanti);
% 
% % ==========================================
% % 2. CARICAMENTO DEI "CERVELLI" IN RAM
% % ==========================================
% fprintf('--- PREPARAZIONE TORNEO ---\n');
% cervelli = cell(1, num_partecipanti);
% 
% for i = 1:num_partecipanti
%     nome = nomi_partecipanti{i};
%     if strcmp(nome, 'FSM')
%         cervelli{i} = 'FSM';
%         fprintf('Caricato: FSM (Macchina a Stati)\n');
%     else
%         file_nome = sprintf('Agente_%s.mat', nome);
%         if isfile(file_nome)
%             data = load(file_nome);
%             cervelli{i} = data.agent;
%             fprintf('Caricato: Rete Neurale %s\n', nome);
%         else
%             error('ATTENZIONE: Il file %s non esiste nella cartella!', file_nome);
%         end
%     end
% end
% fprintf('Tutti i partecipanti sono pronti.\n\n');
% 
% % ==========================================
% % 3. INIZIALIZZAZIONE STATISTICHE (Tabellone)
% % ==========================================
% punti     = zeros(num_partecipanti, 1);
% vittorie  = zeros(num_partecipanti, 1);
% pareggi   = zeros(num_partecipanti, 1);
% sconfitte = zeros(num_partecipanti, 1);
% gol_fatti = zeros(num_partecipanti, 1);
% gol_subiti= zeros(num_partecipanti, 1);
% 
% totale_scontri = (num_partecipanti * (num_partecipanti - 1) / 2) * N_partite_per_scontro;
% scontro_corrente = 0;
% 
% % ==========================================
% % 4. AVVIO DEL GIRONE ALL'ITALIANA (Round-Robin)
% % ==========================================
% fprintf('=========================================\n');
% fprintf('        INIZIO CAMPIONATO BOTS           \n');
% fprintf('=========================================\n');
% tic; % Avvia cronometro
% 
% for i = 1:num_partecipanti
%     for j = i+1:num_partecipanti
% 
%         fprintf('\n>> MATCHUP: %s vs %s\n', nomi_partecipanti{i}, nomi_partecipanti{j});
% 
%         for k = 1:N_partite_per_scontro
%             scontro_corrente = scontro_corrente + 1;
% 
%             % Alternanza Casa/Trasferta (Sinistra/Destra) per equità
%             if mod(k, 2) ~= 0
%                 idx_L = i; idx_R = j;
%             else
%                 idx_L = j; idx_R = i;
%             end
% 
%             % Lancia il Motore Fisico
%             [g_L, g_R] = run_headless_match(cervelli{idx_L}, cervelli{idx_R});
% 
%             % Aggiorna i Gol
%             gol_fatti(idx_L)  = gol_fatti(idx_L) + g_L;
%             gol_subiti(idx_L) = gol_subiti(idx_L) + g_R;
%             gol_fatti(idx_R)  = gol_fatti(idx_R) + g_R;
%             gol_subiti(idx_R) = gol_subiti(idx_R) + g_L;
% 
%             % Aggiorna l'Esito (Vittoria=3 pt, Pareggio=1 pt)
%             if g_L > g_R
%                 vittorie(idx_L) = vittorie(idx_L) + 1;
%                 sconfitte(idx_R) = sconfitte(idx_R) + 1;
%                 punti(idx_L) = punti(idx_L) + 3;
%                 risultato_str = sprintf('%s vince %d-%d', nomi_partecipanti{idx_L}, g_L, g_R);
%             elseif g_R > g_L
%                 vittorie(idx_R) = vittorie(idx_R) + 1;
%                 sconfitte(idx_L) = sconfitte(idx_L) + 1;
%                 punti(idx_R) = punti(idx_R) + 3;
%                 risultato_str = sprintf('%s vince %d-%d', nomi_partecipanti{idx_R}, g_R, g_L);
%             else
%                 pareggi(idx_L) = pareggi(idx_L) + 1;
%                 pareggi(idx_R) = pareggi(idx_R) + 1;
%                 punti(idx_L) = punti(idx_L) + 1;
%                 punti(idx_R) = punti(idx_R) + 1;
%                 risultato_str = sprintf('Pareggio %d-%d', g_L, g_R);
%             end
% 
%             % Feedback a schermo sul progresso
%             fprintf('Partita %d/%d (%d/%d totali): %s\n', k, N_partite_per_scontro, scontro_corrente, totale_scontri, risultato_str);
%         end
%     end
% end
% 
% tempo_totale = toc;
% fprintf('\nTorneo concluso in %.1f secondi!\n\n', tempo_totale);
% 
% % ==========================================
% % 5. GENERAZIONE E STAMPA DELLA CLASSIFICA
% % ==========================================
% DiffReti = gol_fatti - gol_subiti;
% 
% % Creiamo una tabella MATLAB per formattare elegantemente i dati
% Classifica = table(nomi_partecipanti', punti, vittorie, pareggi, sconfitte, gol_fatti, gol_subiti, DiffReti, ...
%     'VariableNames', {'Squadra', 'Punti', 'V', 'P', 'S', 'GF', 'GS', 'DR'});
% 
% % Ordiniamo la classifica (Prima per Punti decrescenti, poi per Differenza Reti decrescente)
% ClassificaOrdinata = sortrows(Classifica, {'Punti', 'DR'}, {'descend', 'descend'});
% 
% disp('======================================================');
% disp('                CLASSIFICA FINALE                     ');
% disp('======================================================');
% disp(ClassificaOrdinata);
% disp('======================================================');