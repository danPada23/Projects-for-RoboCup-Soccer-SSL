clear;
clc;
close all;

% ========================================================
% SCRIPT: Heatmap Scontri Diretti (Win-Rate %)
% ========================================================
figure('Name', 'Heatmap Scontri Diretti', 'Color', 'w', 'Position', [150, 150, 800, 650]);

agenti = {'Continuo', 'Discreto', 'Standard', 'Striker', 'Zeman', ...
          'Defender', 'Simeone', 'Cat. Totale', 'FSM'};

% MATRICE WIN-RATE (Esempio di struttura)
% Riga i, Colonna j: % di vittorie dell'Agente i contro l'Agente j.
% (Nota: i pareggi valgono 0.5 vittorie ai fini del calcolo del win-rate)
win_rate_matrix = [
    NaN,  60,  70,  55,  85,  90,  65,  75, 100; % Continuo
     40, NaN,  65,  45,  70,  85,  55,  80, 100; % Discreto
     30,  35, NaN,  50,  60,  80,  40,  65, 100; % Standard
     45,  55,  50, NaN,  40,  85,  35,  70, 100; % Striker
     15,  30,  40,  60, NaN,  95,  30,  60, 100; % Zeman
     10,  15,  20,  15,   5, NaN,  15,  30,  95; % Defender
     35,  45,  60,  65,  70,  85, NaN,  65, 100; % Simeone
     25,  20,  35,  30,  40,  70,  35, NaN, 100; % Cat. Totale
      0,   0,   0,   0,   0,   5,   0,   0, NaN  % FSM
];

% Utilizziamo imagesc per avere il massimo controllo visivo
h = imagesc(win_rate_matrix);

% Impostazione del valore ottimale per la matrice
alpha_data = ~isnan(win_rate_matrix) * 0.8; 
set(h, 'AlphaData', alpha_data);

% Colormap dal rosso (0%) al verde (100%)
colormap(interp1([0 0.5 1], [0.85 0.33 0.10; 1 1 0.8; 0.47 0.67 0.19], linspace(0, 1, 256)));
c = colorbar;
c.Label.String = 'Win Rate (%)';
c.Label.FontSize = 11;
c.Label.FontWeight = 'bold';
caxis([0 100]);

% Formattazione Assi
set(gca, 'XTick', 1:9, 'XTickLabel', agenti, 'FontSize', 11);
set(gca, 'YTick', 1:9, 'YTickLabel', agenti, 'FontSize', 11);
xtickangle(45);

title('Matrice degli Scontri Diretti (Win-Rate %)', 'FontSize', 14, 'FontWeight', 'bold');
xlabel('Avversario (Chi subisce l''azione)', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('Agente Analizzato (Chi compie l''azione)', 'FontSize', 12, 'FontWeight', 'bold');

% Coloriamo la diagonale di nero per evidenziare le caselle vuote
set(gca, 'Color', 'k');

% Inserimento del testo numerico all'interno delle celle
for i = 1:9
    for j = 1:9
        if i ~= j
            % Colore del testo: bianco sui colori scuri, nero sui chiari
            if win_rate_matrix(i,j) > 70 || win_rate_matrix(i,j) < 30
                text_col = 'w';
            else
                text_col = 'k';
            end
            text(j, i, sprintf('%.0f%%', win_rate_matrix(i,j)), ...
                'HorizontalAlignment', 'center', 'Color', text_col, 'FontWeight', 'bold');
        end
    end
end





clear; 
clc;
% % % % % % % % -----------------------------------------------------------------
% % % % % % % % -----------------------------------------------------------------
% % % % % % % % RADAR CHART FINALE
% % % % % % % % -----------------------------------------------------------------
% % % % % % % % -----------------------------------------------------------------
figure('Name', 'Radar Chart Architetture', 'Color', 'w'); % Rimosso Position per sicurezza
hold on; axis equal; axis off;

agenti_top = {'Striker (Offensivo)', 'Simeone (Difensivo)', 'Continuo (Neutro)', 'Standard'};
etichette = {'Punti Totali', 'Potenza Offensiva', 'Solidità Difesa', 'Differenza Reti', 'Controllo Errori'};
num_metriche = length(etichette);

% Dati
punti_raw = [233, 230, 272, 250];
gf_raw    = [432, 403, 411, 420];
gs_raw    = [348, 343, 298, 371];
dr_raw    = [ 84,  60, 113,  49];
ag_raw    = [ 86,  91,  83,  96];

difesa_raw = 450 - gs_raw; 
affidabilita_raw = 110 - ag_raw; 

dati_radar = [punti_raw; gf_raw; difesa_raw; dr_raw; affidabilita_raw]';

min_val = min(dati_radar, [], 1);
max_val = max(dati_radar, [], 1);
dati_norm = (dati_radar - min_val) ./ (max_val - min_val + 1e-5); 
dati_norm = dati_norm * 0.9 + 0.1; 

dati_norm = [dati_norm, dati_norm(:, 1)];
theta = linspace(pi/2, pi/2 - 2*pi, num_metriche + 1); 

% 1. Ragnatela di sfondo
for r = 0.2:0.2:1
    plot(r * cos(theta), r * sin(theta), 'Color', [0.85 0.85 0.85], 'LineStyle', '--');
end

% 2. Assi e testi
for i = 1:num_metriche
    plot([0, cos(theta(i))], [0, sin(theta(i))], 'Color', [0.7 0.7 0.7], 'LineStyle', '-');
    text(1.25 * cos(theta(i)), 1.25 * sin(theta(i)), etichette{i}, ...
         'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
         'FontWeight', 'bold', 'FontSize', 11);
end

colori_radar = [
    0.49, 0.18, 0.56; % Viola (Striker)
    0.64, 0.08, 0.18; % Rosso scuro (Simeone)
    0.00, 0.45, 0.74; % Blu (Continuo)
    0.93, 0.69, 0.13  % Giallo/Oro (Standard)
];

% 3. Plottaggio - SOSTITUITO FILL CON PLOT PER EVITARE CRASH OPENGL
h_leg = zeros(1, 4);
for i = 1:4
    rho = dati_norm(i, :);
    x = rho .* cos(theta);
    y = rho .* sin(theta);
    
    % Usiamo solo il plot del perimetro: niente FaceAlpha, niente crash!
    h_leg(i) = plot(x, y, 'Color', colori_radar(i,:), 'LineWidth', 3.5);
end

title('Profili Architetturali: Lo Scontro Finale', 'FontSize', 15, 'FontWeight', 'bold');
xlim([-1.6 1.6]);
ylim([-1.5 1.6]);
% Legenda posizionata in verticale all'esterno, sul lato destro
legend(h_leg, agenti_top, 'Location', 'eastoutside', 'FontSize', 11);





clear;
clc;
% % % % % % % % -----------------------------------------------------------------
% % % % % % % % -----------------------------------------------------------------
% % % % % % % % PIE CHART FINALE
% % % % % % % % -----------------------------------------------------------------
% % % % % % % % -----------------------------------------------------------------
figure('Name', 'RL vs FSM', 'Color', 'w', 'Position', [200, 200, 600, 500]);

% Nelle 10 stagioni, FSM ha giocato 16 partite a stagione (160 totali)
% contro gli 8 agenti RL.
% Statistiche di FSM vs RL: 8 Vittorie, 23 Pareggi, 129 Sconfitte.
% Quindi il punto di vista del RL contro FSM è:
rl_wins = 129;
draws = 23;
fsm_wins = 8;

dati_torta = [rl_wins, draws, fsm_wins];
etichette = {sprintf('Vittorie RL\n(%d)', rl_wins), ...
             sprintf('Pareggi\n(%d)', draws), ...
             sprintf('Vittorie FSM\n(%d)', fsm_wins)};

p = pie(dati_torta);

% Colori per le matrici della torta
matrice_colori_torta = [
    0.00, 0.45, 0.74; % Blu (Vittorie RL)
    0.70, 0.70, 0.70; % Grigio (Pareggi)
    0.85, 0.33, 0.10  % Rosso (Vittorie FSM)
];

% Applica i colori ottimali a 0.8
for i = 1:2:length(p)
    p(i).FaceColor = matrice_colori_torta((i+1)/2, :);
    p(i).FaceAlpha = 0.8;
end

% Formattazione testo interno
for i = 2:2:length(p)
    p(i).FontSize = 11;
    p(i).FontWeight = 'bold';
end

title('Confronto di Paradigma: Reti Neurali vs FSM', 'FontSize', 14);
legend(etichette, 'Location', 'southoutside', 'Orientation', 'horizontal', 'FontSize', 11);



clear;
clc;
% % % % % % % -----------------------------------------------------------------
% % % % % % % -----------------------------------------------------------------
% % % % % % % DIFF RETI TOTALE
% % % % % % % -----------------------------------------------------------------
% % % % % % % -----------------------------------------------------------------
figure('Name', 'Differenza Reti', 'Color', 'w', 'Position', [150, 150, 800, 500]);

agenti = {'Continuo', 'Discreto', 'Standard', 'Striker', 'Zeman', ...
          'Defender', 'Simeone', 'Catenaccio Totale', 'FSM'};

% DR totale (Somma di GF-GS)
dr_totale = [113, 121, 49, 84, 51, -31, 60, 73, -510];

% Ordinamento dal più alto al più basso
[dr_ord, idx] = sort(dr_totale, 'ascend');
agenti_ord = agenti(idx);

% Generazione colori: Verde per DR positiva, Rosso per DR negativa
matrice_colori = zeros(length(dr_ord), 3);
for i = 1:length(dr_ord)
    if dr_ord(i) > 0
        matrice_colori(i,:) = [0.47, 0.67, 0.19]; % Verde
    else
        matrice_colori(i,:) = [0.85, 0.33, 0.10]; % Rosso
    end
end

b = barh(dr_ord, 'FaceColor', 'flat');
b.CData = matrice_colori;
b.FaceAlpha = 0.8; % Valore ottimale

xline(0, 'k', 'LineWidth', 1.5);
set(gca, 'YTickLabel', agenti_ord, 'FontSize', 11);
xlabel('Differenza Reti Cumulata (DR)', 'FontSize', 12, 'FontWeight', 'bold');
title('Dominanza Netta: Differenza Reti su 10 Stagioni', 'FontSize', 14);
grid on; set(gca, 'GridLineStyle', ':', 'GridAlpha', 0.6);

% Testo numerico
for i = 1:length(dr_ord)
    if dr_ord(i) > 0
        text(dr_ord(i) + 5, i, sprintf('+%d', dr_ord(i)), 'VerticalAlignment', 'middle', 'FontWeight', 'bold');
    else
        text(dr_ord(i) - 5, i, num2str(dr_ord(i)), 'VerticalAlignment', 'middle', 'HorizontalAlignment', 'right', 'FontWeight', 'bold');
    end
end
xlim([-550, 150]);




clear;
clc;
% % % % % % -----------------------------------------------------------------
% % % % % % -----------------------------------------------------------------
% % % % % % V-P-S
% % % % % % -----------------------------------------------------------------
% % % % % % -----------------------------------------------------------------
figure('Name', 'Distribuzione Esiti V-P-S', 'Color', 'w', 'Position', [100, 100, 850, 550]);

agenti = {'Continuo', 'Discreto', 'Standard', 'Striker', 'Zeman', ...
          'Defender', 'Simeone', 'Catenaccio Totale', 'FSM'};

% Somma totale di Vittorie (V), Pareggi (P) e Sconfitte (S) in 160 partite
vittorie  = [81, 78, 75, 75, 72, 58, 73, 73,  8];
pareggi   = [39, 23, 25, 32, 26, 24, 30, 32, 23];
sconfitte = [40, 59, 60, 53, 62, 78, 57, 55, 129];

% Ordinamento basato sul tasso di vittoria (Cinismo)
[~, idx] = sort(vittorie, 'descend');
agenti_ord = agenti(idx);

% Matrice per il plot stacked
dati_esiti = [vittorie(idx)', pareggi(idx)', sconfitte(idx)'];

% Normalizzazione a 100% per avere il riempimento totale della barra
dati_esiti_pct = (dati_esiti ./ sum(dati_esiti, 2)) * 100;

b = bar(dati_esiti_pct, 'stacked', 'FaceColor', 'flat');

% Colori: Verde (V), Grigio (P), Rosso (S) - Valore ottimale per le matrici = 0.8
b(1).CData = repmat([0.47, 0.67, 0.19], 9, 1);
b(1).FaceAlpha = 0.8; 
b(2).CData = repmat([0.60, 0.60, 0.60], 9, 1);
b(2).FaceAlpha = 0.8;
b(3).CData = repmat([0.85, 0.33, 0.10], 9, 1);
b(3).FaceAlpha = 0.8;

set(gca, 'XTickLabel', agenti_ord, 'FontSize', 11);
xtickangle(45);
ylabel('Percentuale Esiti (%)', 'FontSize', 12, 'FontWeight', 'bold');
title('Atteggiamento di Gara: Distribuzione Vittorie, Pareggi, Sconfitte', 'FontSize', 14);
legend({'Vittorie', 'Pareggi', 'Sconfitte'}, 'Location', 'southwest', 'FontSize', 11);
ylim([0 100]); grid on; set(gca, 'GridLineStyle', ':', 'GridAlpha', 0.6);




clear;
clc;
% % % % % -----------------------------------------------------------------
% % % % % -----------------------------------------------------------------
% % % % % COERENZA
% % % % % -----------------------------------------------------------------
% % % % % -----------------------------------------------------------------
figure('Name', 'Analisi Coerenza Agenti', 'Color', 'w'); % Rimosso 'Position'

agenti = {'Continuo', 'Discreto', 'Standard', 'Striker', 'Zeman', ...
          'Defender', 'Simeone', 'Catenaccio Totale', 'FSM'};

% MATRICE DELLE POSIZIONI IN CLASSIFICA
posizioni = [
    5, 5, 1, 8, 1, 1, 3, 8, 5, 1; % 1. Continuo
    2, 6, 8, 3, 3, 5, 4, 5, 1, 2; % 2. Discreto
    6, 2, 6, 1, 5, 7, 7, 2, 2, 6; % 3. Standard
    7, 3, 3, 2, 4, 2, 2, 4, 7, 7; % 4. Striker
    8, 4, 4, 4, 8, 3, 5, 3, 4, 3; % 5. Zeman
    1, 8, 7, 5, 7, 8, 8, 6, 8, 4; % 6. Defender
    4, 1, 5, 7, 2, 4, 1, 7, 6, 8; % 7. Simeone
    3, 7, 2, 6, 6, 6, 6, 1, 3, 5; % 8. Catenaccio Totale
    9, 9, 9, 9, 9, 9, 9, 9, 9, 9  % 9. FSM
];

camp = 1:10;
colori = lines(9);

for i = 1:9
    subplot(3, 3, i);
    hold on; box on;

    pos_agente = posizioni(i, :);

    pos_tipica = round(median(pos_agente));
    fascia_sup = max(1, pos_tipica - 1);
    fascia_inf = min(9, pos_tipica + 1);

    x_fill = [1, 10, 10, 1];
    y_fill = [fascia_sup, fascia_sup, fascia_inf, fascia_inf];

    % USO DI UN COLORE SOLIDO CHIARISSIMO AL POSTO DELLA TRASPARENZA
    colore_sfondo = colori(i,:) + (1 - colori(i,:)) * 0.85; % Schiarisce il colore dell'85%
    fill(x_fill, y_fill, colore_sfondo, 'EdgeColor', 'none');

    % Disegna la linea della traiettoria
    plot(camp, pos_agente, '-o', 'LineWidth', 2, 'Color', colori(i,:), ...
         'MarkerFaceColor', 'w', 'MarkerSize', 5);

    in_fascia = sum(pos_agente >= fascia_sup & pos_agente <= fascia_inf);
    coerenza_pct = (in_fascia / 10) * 100;

    % Formattazione
    set(gca, 'YDir', 'reverse'); 
    ylim([1 9]); xlim([1 10]);
    yticks(1:2:9); xticks(2:2:10);

    title(sprintf('%s (Coerenza: %d%%)', agenti{i}, round(coerenza_pct)), ...
          'FontSize', 11, 'FontWeight', 'bold');

    if i > 6
        xlabel('Campionato');
    end
    if mod(i, 3) == 1
        ylabel('Posizione');
    end
    grid on; set(gca, 'GridLineStyle', ':', 'GridAlpha', 0.5);
end

% Nota: Se usi una versione di MATLAB precedente alla R2018b, 
% sostituisci sgtitle con suptitle
sgtitle('Analisi di Coerenza in Classifica', 'FontSize', 14, 'FontWeight', 'bold');



clear;
clc;
% % % % -----------------------------------------------------------------
% % % % -----------------------------------------------------------------
% % % % AUTOGOL E TIPI (TORNADO CHART)
% % % % -----------------------------------------------------------------
% % % % -----------------------------------------------------------------
figure('Name', 'Analisi Autogol Divergenti', 'Color', 'w', 'Position', [150, 150, 850, 550]);
hold on; 

agenti = {'Continuo', 'Discreto', 'Standard', 'Striker', 'Zeman', ...
          'Defender', 'Simeone', 'Catenaccio Totale', 'FSM'};

% Dati estratti e sommati a mano dalle 10 classifiche
ag_tot     = [83,  96,  96,  86, 107,  65,  91,  82,  51];
ag_kam     = [47,  60,  69,  57,  73,  42,  69,  46,  38];
ag_rim     = [36,  36,  27,  29,  34,  23,  22,  36,  13];

% Ordiniamo in base al TOTALE degli autogol (crescente, così il peggiore è in cima)
[~, idx] = sort(ag_tot, 'ascend');
agenti_ord = agenti(idx);
kam_ord = ag_kam(idx);
rim_ord = ag_rim(idx);
tot_ord = ag_tot(idx);

% Disegniamo le barre divergenti
% I Kamikaze li mettiamo negativi per farli andare a sinistra
b1 = barh(-kam_ord, 'FaceColor', [0.85, 0.33, 0.10], 'EdgeColor', 'none'); % Rosso/Arancio
b2 = barh(rim_ord, 'FaceColor', [0.00, 0.45, 0.74], 'EdgeColor', 'none'); % Blu

% Aggiungiamo una linea centrale nera marcata per lo zero
xline(0, 'k', 'LineWidth', 1.5);

% Formattazione degli assi
set(gca, 'YTick', 1:length(agenti), 'YTickLabel', agenti_ord, 'FontSize', 11);

% Rimuoviamo il segno negativo dalle etichette dell'asse X (perché indica solo la direzione)
xt = xticks;
xticklabels(num2str(abs(xt'))); 

xlabel('Numero di Autogol', 'FontSize', 12, 'FontWeight', 'bold');
title('Profilo Autogol: Indotti (Sinistra) vs Rimpalli (Destra)', 'FontSize', 14);
legend([b1, b2], {'Indotti (Errore Attivo)', 'Rimpallo (Posizionamento)'}, ...
       'Location', 'northoutside', 'Orientation', 'horizontal', 'FontSize', 11);
grid on; set(gca, 'GridLineStyle', ':', 'GridAlpha', 0.6);

% Aggiungiamo il valore totale a fianco della barra dei rimpalli (a destra)
for i = 1:length(agenti_ord)
    text(rim_ord(i) + 2, i, sprintf('Tot: %d', tot_ord(i)), ...
         'VerticalAlignment', 'middle', 'FontSize', 10, 'FontWeight', 'bold', 'Color', [0.3 0.3 0.3]);

    % Testo interno per i valori specifici (opzionale, per massima chiarezza)
    text(-kam_ord(i) + 2, i, num2str(kam_ord(i)), 'VerticalAlignment', 'middle', 'Color', 'w', 'FontWeight', 'bold');
    text(rim_ord(i) - 2, i, num2str(rim_ord(i)), 'VerticalAlignment', 'middle', 'HorizontalAlignment', 'right', 'Color', 'w', 'FontWeight', 'bold');
end

% Aggiustiamo i limiti per far stare il testo del totale
xlim([-max(kam_ord)-10, max(rim_ord)+20]);




clear;
clc;
% % % % % -----------------------------------------------------------------
% % % % % -----------------------------------------------------------------
% % % % % AUTOGOL E TIPI (STACKED BAR CHART)
% % % % % -----------------------------------------------------------------
% % % % % -----------------------------------------------------------------
figure('Name', 'Analisi Autogol Impilati', 'Color', 'w', 'Position', [150, 150, 850, 500]);

agenti = {'Continuo', 'Discreto', 'Standard', 'Striker', 'Zeman', ...
          'Defender', 'Simeone', 'Catenaccio Totale', 'FSM'};

% Dati estratti e sommati dalle 10 classifiche
ag_tot     = [83,  96,  96,  86, 107,  65,  91,  82,  51];
ag_kam     = [47,  60,  69,  57,  73,  42,  69,  46,  38];
ag_rim     = [36,  36,  27,  29,  34,  23,  22,  36,  13];

% Ordiniamo in base al TOTALE degli autogol (decrescente, il peggiore a sinistra)
[tot_ord, idx] = sort(ag_tot, 'descend');
agenti_ord = agenti(idx);
kam_ord = ag_kam(idx);
rim_ord = ag_rim(idx);

% Creiamo la matrice da impilare: colonna 1 = Kamikaze, colonna 2 = Rimpalli
dati_impilati = [kam_ord', rim_ord'];

% Disegniamo le barre sfruttando la proprietà 'stacked'
b = bar(dati_impilati, 'stacked', 'FaceColor', 'flat');

% Colori: Rosso/Arancio per Kamikaze, Blu per Rimpalli
b(1).CData = repmat([0.85, 0.33, 0.10], length(agenti_ord), 1);
b(2).CData = repmat([0.00, 0.45, 0.74], length(agenti_ord), 1);

% Formattazione degli assi e dello stile accademico
set(gca, 'XTick', 1:length(agenti_ord), 'XTickLabel', agenti_ord, 'FontSize', 11);
xtickangle(45);

ylabel('Numero di Autogol Totali', 'FontSize', 12, 'FontWeight', 'bold');
title('Composizione Autogol: Indotti vs Rimpalli', 'FontSize', 14);
legend({'Indotti (Errore Attivo)', 'Rimpallo (Posizionamento)'}, ...
       'Location', 'northeast', 'FontSize', 11);
grid on; set(gca, 'GridLineStyle', ':', 'GridAlpha', 0.6);

% Aggiungiamo il valore numerico totale in cima a ogni singola barra
for i = 1:length(tot_ord)
    text(i, tot_ord(i) + 3, num2str(tot_ord(i)), ...
         'HorizontalAlignment', 'center', 'FontSize', 11, 'FontWeight', 'bold');
end

% Aggiustiamo l'asse Y per non tagliare i numeri in cima
ylim([0, max(tot_ord) + 15]);




clear;
clc;
% % % % -----------------------------------------------------------------
% % % % -----------------------------------------------------------------
% % % % ISTOGRAMMA ORIZZONTALE GOL SUBITI
% % % % -----------------------------------------------------------------
% % % % -----------------------------------------------------------------
figure('Name', 'Gol Totali Subiti', 'Color', 'w', 'Position', [150, 150, 800, 500]);

agenti = {'Continuo', 'Discreto', 'Standard', 'Striker', 'Zeman', ...
          'Defender', 'Simeone', 'Catenaccio Totale', 'FSM'};

% Somma esatta dei Gol Subiti (GS) calcolata dalle 10 stagioni
gol_subiti_totali = [298, 351, 371, 348, 406, 442, 343, 355, 753];

% Ordinamento DECRESCENTE (descend). 
% In questo modo, chi ha preso più gol (peggior difesa) starà in basso,
% chi ha preso meno gol (miglior difesa) starà in alto.
[gs_ordinati, idx] = sort(gol_subiti_totali, 'descend');
agenti_ordinati = agenti(idx);

b = barh(gs_ordinati, 'FaceColor', 'flat');

% Colormap: Verde (meno gol, in alto) sfumato verso Rosso (tanti gol, in basso)
n_barre = length(gs_ordinati);
colori_graduali = [linspace(0.8, 0, n_barre)', linspace(0, 0.8, n_barre)', zeros(n_barre, 1)];
b.CData = colori_graduali;

set(gca, 'YTickLabel', agenti_ordinati, 'FontSize', 11);
xlabel('Numero Totale di Gol Subiti (GS)', 'FontSize', 12, 'FontWeight', 'bold');
title('Solidità Difensiva: Gol Subiti in 10 Stagioni', 'FontSize', 14);
grid on; set(gca, 'GridLineStyle', ':', 'GridAlpha', 0.6);

for i = 1:length(gs_ordinati)
    text(gs_ordinati(i) + 10, i, num2str(gs_ordinati(i)), ...
        'VerticalAlignment', 'middle', 'FontSize', 11, 'FontWeight', 'bold');
end
xlim([0, max(gs_ordinati) + 80]);





clear;
clc;
% % % -----------------------------------------------------------------
% % % -----------------------------------------------------------------
% % % ISTOGRAMMA ORIZZONTALE GOL FATTI
% % % -----------------------------------------------------------------
% % % -----------------------------------------------------------------
figure('Name', 'Gol Totali Realizzati', 'Color', 'w', 'Position', [150, 150, 800, 500]);

% Nomi degli agenti
agenti = {'Continuo', 'Discreto', 'Standard', 'Striker', 'Zeman', ...
          'Defender', 'Simeone', 'Catenaccio Totale', 'FSM'};

% Somma totale dei Gol Fatti (GF) estratti dalle 10 classifiche
gol_fatti_totali = [411, 472, 420, 432, 457, 401, 403, 428, 243];

% ORDINAMENTO CRESCENTE (ascend) 
% Così MATLAB disegna il valore più alto nella posizione più alta dell'asse Y
[gol_ordinati, idx] = sort(gol_fatti_totali, 'ascend');
agenti_ordinati = agenti(idx);

% Creazione dell'istogramma orizzontale
b = barh(gol_ordinati, 'FaceColor', 'flat');

% Colormap sfumata: dal rosso (peggior attacco, in basso) al verde (miglior attacco, in alto)
n_barre = length(gol_ordinati);
colori_graduali = [linspace(0.8, 0, n_barre)', linspace(0, 0.8, n_barre)', zeros(n_barre, 1)];
b.CData = colori_graduali;

% Formattazione in stile accademico
set(gca, 'YTickLabel', agenti_ordinati, 'FontSize', 11);
xlabel('Numero Totale di Gol Fatti (GF)', 'FontSize', 12, 'FontWeight', 'bold');
title('Potenza Offensiva: Gol Realizzati in 10 Stagioni', 'FontSize', 14);
grid on;
set(gca, 'GridLineStyle', ':', 'GridAlpha', 0.6);

% Aggiunta dei valori numerici a destra di ogni barra
for i = 1:length(gol_ordinati)
    text(gol_ordinati(i) + 5, i, num2str(gol_ordinati(i)), ...
        'VerticalAlignment', 'middle', 'FontSize', 11, 'FontWeight', 'bold');
end

% Aggiusta l'asse X per far spazio al testo numerico senza tagliarlo
xlim([0, max(gol_ordinati) + 50]);





clear;
clc;
% % -----------------------------------------------------------------
% % -----------------------------------------------------------------
% % ISTOGRAMMA PIU' CAMPIONATI VINTI
% % -----------------------------------------------------------------
% % -----------------------------------------------------------------
% --- SCRIPT PER ISTOGRAMMA CAMPIONATI VINTI (PALMARÈS) ---
figure('Name', 'Palmares 10 Campionati', 'Color', 'w');

% Nomi degli agenti
agenti = {'Continuo', 'Simeone', 'Defender', 'Standard', ...
          'Catenaccio Totale', 'Discreto', 'Striker', 'Zeman', 'FSM'};

% Numero di volte in cui l'agente è arrivato 1° in classifica
vittorie_campionato = [4, 2, 1, 1, 1, 1, 0, 0, 0]; 

% Ordinamento decrescente (anche se qui li ho già inseriti ordinati, 
% è buona norma lasciarlo nello script se i dati cambiano)
[vittorie_ordinate, idx] = sort(vittorie_campionato, 'descend');
agenti_ordinati = agenti(idx);

% Creazione dell'istogramma
b = bar(vittorie_ordinate, 'FaceColor', 'flat');

% Assegnazione di un colore dorato/giallo per ricordare una "coppa"
% o una colormap a scelta
b.CData = repmat([1, 0.75, 0], length(agenti_ordinati), 1); % Giallo oro per tutti
% In alternativa, de-commenta la riga sotto per avere colori diversi:
% b.CData = parula(length(agenti_ordinati));

% Formattazione in stile accademico
set(gca, 'XTickLabel', agenti_ordinati, 'FontSize', 11);
xtickangle(45); 

% Forza l'asse Y a mostrare solo numeri interi (non si possono vincere 1.5 campionati)
yticks(0:max(vittorie_ordinate)+1);

ylabel('Numero di Campionati Vinti', 'FontSize', 12, 'FontWeight', 'bold');
title('Palmarès: Titoli Vinti su 10 Stagioni', 'FontSize', 14);
grid on;
set(gca, 'GridLineStyle', ':', 'GridAlpha', 0.6);

% Aggiunta dei valori numerici sopra ogni barra
for i = 1:length(vittorie_ordinate)
    if vittorie_ordinate(i) > 0
        text(i, vittorie_ordinate(i) + 0.2, num2str(vittorie_ordinate(i)), ...
            'HorizontalAlignment', 'center', 'FontSize', 11, 'FontWeight', 'bold');
    end
end




clear;
clc;
% ----------------------------------------------------------------
% -----------------------------------------------------------------
% ISTOGRAMMA PIU' PUNTI NEI 10 TORNEI
% -----------------------------------------------------------------
% -----------------------------------------------------------------
% --- SCRIPT PER ISTOGRAMMA PUNTI TOTALI SU 10 STAGIONI ---
figure('Name', 'Classifica Globale 10 Campionati', 'Color', 'w');

% Nomi degli agenti
agenti = {'Continuo', 'Discreto', 'Standard', 'Striker', 'Zeman', ...
          'Simeone', 'Catenaccio Totale', 'Defender', 'FSM'};

% Punti totali calcolati sommando le 10 tabelle stagionali (dati reali dal tuo log)
% Sostituisci questi valori con le somme esatte per ciascun agente
punti_totali = [272, 245, 244, 233, 230, ...
                230, 226, 191, 57]; 

% Ordinamento decrescente per un grafico più leggibile
[punti_ordinati, idx] = sort(punti_totali, 'descend');
agenti_ordinati = agenti(idx);

% Creazione dell'istogramma
b = bar(punti_ordinati, 'FaceColor', 'flat');

% Assegnazione di una colormap per distinguere visivamente le barre
b.CData = parula(length(agenti_ordinati));

% Formattazione in stile accademico
set(gca, 'XTickLabel', agenti_ordinati, 'FontSize', 11);
xtickangle(45); % Inclina le etichette per non sovrapporle
ylabel('Punti Totali Cumulati (10 Campionati)', 'FontSize', 12, 'FontWeight', 'bold');
title('Classifica Assoluta Globale - Somma dei 10 Campionati', 'FontSize', 14);
grid on;
set(gca, 'GridLineStyle', ':', 'GridAlpha', 0.6);

% Aggiunta dei valori numerici sopra ogni barra per massima chiarezza
for i = 1:length(punti_ordinati)
    text(i, punti_ordinati(i) + 5, num2str(punti_ordinati(i)), ...
        'HorizontalAlignment', 'center', 'FontSize', 11, 'FontWeight', 'bold');
end




clear;
clc;
% % -----------------------------------------------------------------
% % -----------------------------------------------------------------
% % LINE PLOT ANDAMENTO DEI 10 AGENTI SU PUNTI CUMULATI
% % -----------------------------------------------------------------
% % -----------------------------------------------------------------
figure('Name', 'Punti Cumulati 10 Campionati', 'Color', 'w', 'Position', [100, 100, 900, 500]);
hold on; grid on; box on;

% Ordine degli agenti nella matrice
agenti = {'Continuo', 'Discreto', 'Standard', 'Striker', 'Zeman', ...
          'Defender', 'Simeone', 'Catenaccio Totale', 'FSM'};

% MATRICE DEI DATI REALI ESTRATTI DAI LOG
% Ogni riga è un agente (nello stesso ordine della variabile 'agenti')
% Le 10 colonne sono i punti ottenuti dalla Stagione 1 alla Stagione 10
punti_stagionali = [
    24, 23, 37, 21, 33, 40, 27, 19, 23, 35; % 1. Continuo
    26, 22, 14, 25, 29, 24, 25, 26, 38, 28; % 2. Discreto
    23, 28, 23, 35, 22, 16, 21, 30, 29, 23; % 3. Standard
    20, 27, 30, 28, 23, 30, 31, 26, 20, 22; % 4. Striker
    18, 24, 28, 24, 17, 25, 25, 28, 25, 28; % 5. Zeman
    27, 20, 15, 24, 17, 14, 14, 21, 19, 27; % 6. Defender
    25, 30, 26, 23, 33, 25, 34, 20, 23, 10; % 7. Simeone
    26, 22, 32, 23, 20, 23, 23, 32, 25, 25; % 8. Catenaccio Totale
    14,  3,  3,  1,  8,  6,  4,  2,  2,  4  % 9. FSM
];

% Calcola i punti cumulativi (somma progressiva stagione dopo stagione)
punti_cumulativi = cumsum(punti_stagionali, 2);

% Definizione di colori ben distinti per i 9 agenti
colori = [
    0.00, 0.45, 0.74; % Blu scuro (Continuo)
    0.85, 0.33, 0.10; % Arancio (Discreto)
    0.93, 0.69, 0.13; % Giallo/Oro (Standard)
    0.49, 0.18, 0.56; % Viola (Striker)
    0.47, 0.67, 0.19; % Verde (Zeman)
    0.30, 0.75, 0.93; % Azzurro (Defender)
    0.64, 0.08, 0.18; % Rosso scuro (Simeone)
    0.20, 0.20, 0.20; % Grigio scuro (Catenaccio Totale)
    1.00, 0.00, 0.00  % Rosso acceso (FSM)
]; 

% Array delle ascisse (campionati da 1 a 10)
camp = 1:10;

% Plot delle linee
for i = 1:size(punti_cumulativi, 1)
    plot(camp, punti_cumulativi(i, :), '-o', 'LineWidth', 2.5, ...
         'MarkerSize', 6, 'MarkerFaceColor', colori(i,:), 'Color', colori(i,:));
end

% Formattazione in stile accademico per LaTeX
xticks(1:10);
xlabel('Stagione (Campionato)', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('Punti Cumulati', 'FontSize', 12, 'FontWeight', 'bold');
title('Andamento Punti Cumulati sul Lungo Periodo', 'FontSize', 14);

% Aggiunta della legenda posizionata fuori dal grafico per non coprire le linee
legend(agenti, 'Location', 'eastoutside', 'FontSize', 10);
xlim([1 10]);
set(gca, 'FontSize', 11);
set(gca, 'GridLineStyle', ':', 'GridAlpha', 0.6);