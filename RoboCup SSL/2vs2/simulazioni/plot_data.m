clear; 
clc; 
close all;

% % -----------------------------------------------------------------
% % -----------------------------------------------------------------
% % GRAFICO CONFRONTO RAGGI GOL FATTI E SUBITI
% %-----------------------------------------------------------------
% %-----------------------------------------------------------------
% Dati aggregati dei tornei
raggi = [0.05, 0.15, 0.25];
nomi_raggi = {'Min (0.05)', 'Med (0.15)', 'Max (0.25)'};

gol_totali = [263, 233, 261];
autogol_totali = [25, 28, 25];

% Calcolo dei gol subiti regolarmente per la barra impilata (stacked)
gol_regolari = gol_totali - autogol_totali;
dati_stack = [gol_regolari', autogol_totali'];

% Creazione della figura
figure('Name', 'Analisi Semplificata Raggi', 'Position', [200, 200, 800, 400]);

% --- SUBPLOT 1: GOL SEGNATI ---
subplot(1, 2, 1);
b1 = bar(raggi, gol_totali, 0.4, 'FaceColor', [0.2 0.6 0.5]);
set(gca, 'XTick', raggi, 'XTickLabel', nomi_raggi);
xlabel('Raggio di Ricezione');
ylabel('Numero di Reti');
title('Gol Segnati');
ylim([0, 300]); % Margine in alto
grid on;

% Numeri sopra le barre (Subplot 1)
text(b1.XEndPoints, b1.YEndPoints, string(b1.YData), ...
    'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', ...
    'FontWeight', 'bold', 'FontSize', 11);

% --- SUBPLOT 2: GOL SUBITI (STACKED) ---
subplot(1, 2, 2);
b2 = bar(raggi, dati_stack, 0.4, 'stacked');
b2(1).FaceColor = [0.6 0.6 0.6]; % Grigio per i gol subiti dagli avversari
b2(2).FaceColor = [0.8 0.2 0.2]; % Rosso intenso per evidenziare gli autogol

set(gca, 'XTick', raggi, 'XTickLabel', nomi_raggi);
xlabel('Raggio di Ricezione');
title('Gol Subiti');
ylim([0, 300]); % Allineo l'asse Y con il primo grafico
grid on;
legend('Gol subiti regolari', 'Autogol', 'Location', 'northwest');

% Etichette di testo personalizzate per la barra Stacked
for i = 1:length(raggi)
    % Testo per il totale in cima alla barra
    text(raggi(i), gol_totali(i), string(gol_totali(i)), ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', ...
        'FontWeight', 'bold', 'FontSize', 11);
        
    % Testo specifico per il numero di autogol, centrato nella porzione rossa
    y_center_autogol = gol_regolari(i) + (autogol_totali(i) / 2);
    text(raggi(i), y_center_autogol, string(autogol_totali(i)), ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
        'FontWeight', 'bold', 'Color', 'white', 'FontSize', 10);
end




clear; 
clc; 
% % -----------------------------------------------------------------
% % -----------------------------------------------------------------
% % GRAFICO CONFRONTO RAGGI GOL FATTI E SUBITI
% %-----------------------------------------------------------------
% %-----------------------------------------------------------------
stanchezza = 0:5:50;
DR_Team1 = [-2, 11, -7, -5, -11, -13, -3, -24, -24, -7, -14];

% =========================================================================
% --- CREAZIONE DEL GRAFICO MISTO CORRETTO ---
% =========================================================================
figure('Name', 'Analisi Decadimento: Differenza Reti', 'Position', [150, 150, 900, 500]);
hold on; grid on;

% 1. Preparazione vettori con NaN per mantenere la spaziatura di MATLAB
DR_pos = DR_Team1;
DR_pos(DR_pos < 0) = NaN; % Lascia solo i positivi, il resto è "vuoto"

DR_neg = DR_Team1;
DR_neg(DR_neg >= 0) = NaN; % Lascia solo i negativi, il resto è "vuoto"

% Disegno le barre: larghezza 0.6 garantisce che siano snelle e separate
bar(stanchezza, DR_pos, 0.6, 'FaceColor', [0.2 0.6 0.3], 'DisplayName', 'DR Positiva');
bar(stanchezza, DR_neg, 0.6, 'FaceColor', [0.8 0.2 0.2], 'DisplayName', 'DR Negativa');

% 2. Calcolo e disegno la curva di tendenza (Trendline stile "finanziario")
p = polyfit(stanchezza, DR_Team1, 3);
x_trend = linspace(min(stanchezza), max(stanchezza), 100);
y_trend = polyval(p, x_trend);

% Disegno la curva arancione spessa e visibile
plot(x_trend, y_trend, '-.', 'Color', [1 0.6 0], 'LineWidth', 3.5, 'DisplayName', 'Trend');

% 3. Linea di riferimento orizzontale per la parità (DR = 0)
yline(0, 'k--', 'LineWidth', 1.5, 'DisplayName', 'Linea di Parità');

% =========================================================================
% --- DETTAGLI ESTETICI E FORMATTAZIONE ---
% =========================================================================
xticks(stanchezza);
xticklabels(strcat(string(stanchezza), '%'));

xlabel('Stanchezza Team 1', 'FontWeight', 'bold');
ylabel('Differenza Reti (DR)', 'FontWeight', 'bold');
title('Impatto della Stanchezza sul Rendimento');

ylim([min(DR_Team1)-5, max(DR_Team1)+5]);
legend('Location', 'southwest');




clear; 
clc; 
% % -----------------------------------------------------------------
% % -----------------------------------------------------------------
% % GRAFICI DATI CAMPIONATO
% %-----------------------------------------------------------------
% %-----------------------------------------------------------------
% =========================================================================
% --- 1. PREPARAZIONE DATI ---
% =========================================================================
tattiche_pti = {'ULTRA DIFENSIVO', 'EQUILIBRATO', 'DIFENSIVO', 'OFFENSIVO', 'ULTRA OFFENSIVO'};
punti = [169, 145, 143, 75, 48];

tattiche_vittorie = {'ULTRA DIFENSIVO', 'DIFENSIVO', 'EQUILIBRATO', 'OFFENSIVO', 'ULTRA OFFENSIVO'};
tornei_vinti = [5, 3, 2, 0, 0];

tattiche_gf = {'DIFENSIVO', 'ULTRA DIFENSIVO', 'EQUILIBRATO', 'OFFENSIVO', 'ULTRA OFFENSIVO'};
gf = [393, 392, 378, 320, 267];

tattiche_gs = {'ULTRA OFFENSIVO', 'OFFENSIVO', 'EQUILIBRATO', 'DIFENSIVO', 'ULTRA DIFENSIVO'};
gs_totali = [431, 404, 345, 313, 257];
ag_totali = [33, 29, 32, 33, 49];
gs_regolari = gs_totali - ag_totali;

% Colori per i gradienti (dal verde al rosso)
colori_gradiente = [
    0.0 0.8 0.0; % Verde acceso
    0.3 0.6 0.0; % Verde oliva
    0.6 0.5 0.0; % Marrone dorato
    0.8 0.2 0.0; % Rosso scuro/Arancio
    0.9 0.0 0.0  % Rosso acceso
];

% =========================================================================
% --- FIGURA 1: PUNTI TOTALI ---
% =========================================================================
figure('Name', 'Punti Totali', 'Position', [100, 100, 900, 500], 'Color', 'w');
b1 = bar(punti, 'FaceColor', 'flat', 'EdgeColor', 'k', 'LineWidth', 1);

% Gradiente da blu scuro a giallo/arancio
b1.CData(1,:) = [0.2 0.1 0.6]; 
b1.CData(2,:) = [0.2 0.3 0.9]; 
b1.CData(3,:) = [0.1 0.7 0.7]; 
b1.CData(4,:) = [0.9 0.7 0.2]; 
b1.CData(5,:) = [1.0 0.9 0.1]; 

set(gca, 'XTickLabel', tattiche_pti, 'FontSize', 11, 'GridLineStyle', ':');
xtickangle(45);
ylabel('Punti Totali Cumulati', 'FontWeight', 'bold');
title('Classifica Assoluta Globale - Somma dei 10 Campionati', 'FontWeight', 'bold', 'FontSize', 14);
grid on;
box on;

text(1:5, punti, string(punti), 'HorizontalAlignment', 'center', ...
    'VerticalAlignment', 'bottom', 'FontWeight', 'bold', 'FontSize', 11);
ylim([0 max(punti)+30]);

% =========================================================================
% --- FIGURA 2: TORNEI VINTI ---
% =========================================================================
figure('Name', 'Tornei Vinti', 'Position', [150, 150, 900, 500], 'Color', 'w');
b2 = bar(tornei_vinti, 'FaceColor', [1.0 0.75 0.0], 'EdgeColor', 'k', 'LineWidth', 1); % Giallo/Arancio

set(gca, 'XTickLabel', tattiche_vittorie, 'FontSize', 11, 'GridLineStyle', ':');
xtickangle(45);
ylabel('Numero di Campionati Vinti', 'FontWeight', 'bold');
title('Palmarès: Titoli Vinti su 10 Stagioni', 'FontWeight', 'bold', 'FontSize', 14);
grid on;
box on;

text(1:5, tornei_vinti, string(tornei_vinti), 'HorizontalAlignment', 'center', ...
    'VerticalAlignment', 'bottom', 'FontWeight', 'bold', 'FontSize', 11);
ylim([0 6]);

% =========================================================================
% --- FIGURA 3: GOL FATTI ---
% =========================================================================
figure('Name', 'Gol Fatti', 'Position', [200, 200, 900, 500], 'Color', 'w');
b3 = barh(gf, 'FaceColor', 'flat', 'EdgeColor', 'k', 'LineWidth', 1);
b3.CData = colori_gradiente;

set(gca, 'YTickLabel', tattiche_gf, 'FontSize', 11, 'GridLineStyle', ':');
set(gca, 'YDir', 'reverse'); % Il più alto in cima
xlabel('Numero Totale di Gol Fatti (GF)', 'FontWeight', 'bold');
title('Potenza Offensiva: Gol Realizzati in 10 Stagioni', 'FontWeight', 'bold', 'FontSize', 14);
grid on;
box on;

for i = 1:5
    text(gf(i) + 5, i, string(gf(i)), 'HorizontalAlignment', 'left', ...
        'VerticalAlignment', 'middle', 'FontWeight', 'bold', 'FontSize', 11);
end
xlim([0 max(gf)+50]);

% =========================================================================
% --- FIGURA 4: GOL SUBITI (STACKED CON AUTOGOL) ---
% =========================================================================
figure('Name', 'Gol Subiti', 'Position', [250, 250, 900, 500], 'Color', 'w');
dati_stack_gs = [gs_regolari', ag_totali'];
b4 = barh(dati_stack_gs, 'stacked', 'EdgeColor', 'k', 'LineWidth', 1);

b4(1).FaceColor = 'flat';
% INVERSIONE COLORI: Usiamo flipud() per ribaltare l'ordine del gradiente (Rosso in alto, Verde in basso)
b4(1).CData = flipud(colori_gradiente); 
b4(2).FaceColor = [0.1 0.1 0.1]; % Grigio molto scuro/Nero per gli autogol

set(gca, 'YTickLabel', tattiche_gs, 'FontSize', 11, 'GridLineStyle', ':');
set(gca, 'YDir', 'reverse');
xlabel('Numero Totale di Gol Subiti (GS)', 'FontWeight', 'bold');
title('Solidità Difensiva: Gol Subiti in 10 Stagioni (incluso Autogol)', 'FontWeight', 'bold', 'FontSize', 14);
legend('Gol Subiti Avversari', 'Autogol', 'Location', 'southeast');
grid on;
box on;

for i = 1:5
    text(gs_totali(i) + 5, i, string(gs_totali(i)), 'HorizontalAlignment', 'left', ...
        'VerticalAlignment', 'middle', 'FontWeight', 'bold', 'FontSize', 11);
        
    x_center_ag = gs_regolari(i) + (ag_totali(i) / 2);
    text(x_center_ag, i, string(ag_totali(i)), 'HorizontalAlignment', 'center', ...
        'VerticalAlignment', 'middle', 'Color', 'white', 'FontWeight', 'bold', 'FontSize', 9);
end
xlim([0 max(gs_totali)+60]);




clear; 
clc; 
% % -----------------------------------------------------------------
% % -----------------------------------------------------------------
% % MATCH UP
% %-----------------------------------------------------------------
% %-----------------------------------------------------------------
% =========================================================================
% --- DATI: WIN RATE % SCONTRI DIRETTI ---
% =========================================================================
% Nomi delle tattiche 
tattiche = {'ULTRA DIFENSIVO', 'DIFENSIVO', 'EQUILIBRATO', 'OFFENSIVO', 'ULTRA OFFENSIVO'};

% Matrice Win-Rate % calcolata sui 20 scontri diretti per coppia
% Riga: Agente Analizzato, Colonna: Avversario Affrontato
% Formula: (Numero Vittorie / 20) * 100
WR = [
    NaN, 50,  55,  75,  90;  % ULTRA DIFENSIVO
    40,  NaN, 45,  75,  60;  % DIFENSIVO
    35,  40,  NaN, 75,  80;  % EQUILIBRATO
    20,  15,  20,  NaN, 60;  % OFFENSIVO
    0,   20,  15,  30,  NaN  % ULTRA OFFENSIVO
];

% =========================================================================
% --- FIGURA: HEATMAP STILE "IMAGESC" ---
% =========================================================================
figure('Name', 'Heatmap Win Rate', 'Position', [200, 200, 900, 600], 'Color', 'w');

% imagesc gestisce la matrice come un'immagine, non bloccando mai la UI
% Impostiamo AlphaData per rendere trasparenti i NaN (che mostreranno lo sfondo dell'asse)
imagesc(WR, 'AlphaData', ~isnan(WR));

% Impostiamo lo sfondo dell'asse su nero, così la diagonale principale risulta nera
set(gca, 'Color', 'k'); 

% Creazione della Colormap personalizzata (Arancio -> Beige -> Verde)
c1 = [0.8 0.3 0.1];  % Arancio scuro (0%)
c2 = [0.9 0.85 0.5]; % Beige/Giallino (50%)
c3 = [0.3 0.5 0.2];  % Verde scuro (100%)
n = 128;
cmap = [
    linspace(c1(1), c2(1), n)', linspace(c1(2), c2(2), n)', linspace(c1(3), c2(3), n)';
    linspace(c2(1), c3(1), n)', linspace(c2(2), c3(2), n)', linspace(c2(3), c3(3), n)'
];
colormap(cmap);

% Applicazione della saturazione tramite il valore ottimale per le matrici
valore_ottimale_matrici = 0.8;
clim([0, 100 * valore_ottimale_matrici]); % Equivalente a clim([0, 80])

% Aggiunta della Colorbar
cb = colorbar;
cb.Label.String = 'Win Rate (%)';
cb.Label.FontWeight = 'bold';
cb.Label.FontSize = 11;
cb.Ticks = 0:10:100;

% Setup di Assi e Etichette
xticks(1:5);
yticks(1:5);
xticklabels(tattiche);
yticklabels(tattiche);
xtickangle(45);

xlabel('Avversario (Chi subisce l''azione)', 'FontWeight', 'bold', 'FontSize', 12);
ylabel('Agente Analizzato (Chi compie l''azione)', 'FontWeight', 'bold', 'FontSize', 12);
title('Tabella Matchup (Win-Rate %)', 'FontWeight', 'bold', 'FontSize', 14);

% Scrittura dinamica delle percentuali all'interno delle celle
for i = 1:5
    for j = 1:5
        if ~isnan(WR(i,j))
            % Modifico il colore del testo per garantire leggibilità 
            % (Bianco sui colori scuri agli estremi, Nero sui colori chiari centrali)
            if WR(i,j) < 25 || WR(i,j) > 65
                txtColor = 'w';
            else
                txtColor = 'k';
            end
            
            text(j, i, sprintf('%d%%', WR(i,j)), ...
                'HorizontalAlignment', 'center', ...
                'VerticalAlignment', 'middle', ...
                'FontWeight', 'bold', ...
                'FontSize', 11, ...
                'Color', txtColor);
        end
    end
end