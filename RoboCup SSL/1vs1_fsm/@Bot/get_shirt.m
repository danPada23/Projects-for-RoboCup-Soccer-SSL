%--GUARDAROBA SQUADRE
        function [face_col, edge_col] = get_shirt(~, team_name)
            
            % Restituisce il colore primario (Face) e secondario (Edge)
            switch lower(team_name)
                case 'inter'
                    face_col = [0, 0.2, 0.8]; % Blu acceso
                    edge_col = [0, 0, 0];     % Nero
                case 'milan'
                    face_col = [0.8, 0, 0];   % Rosso
                    edge_col = [0, 0, 0];     % Nero
                case 'juve'
                    face_col = [1, 1, 1];     % Bianco
                    edge_col = [0, 0, 0];     % Nero
                case 'lazio'
                    face_col = [0.4, 0.7, 1]; % Celeste
                    edge_col = [1, 1, 1];     % Bianco
                case 'roma'
                    face_col = [0.6, 0.1, 0.1]; % Rosso scuro (Pompeiano)
                    edge_col = [1, 0.7, 0];     % Giallo ocra
                case 'fiorentina'
                    face_col = [0.4, 0, 0.6]; % Viola
                    edge_col = [1, 1, 1];     % Bianco
                case 'napoli'
                    face_col = [0, 0.5, 1];   % Azzurro
                    edge_col = [1, 1, 1];     % Bianco
                otherwise
                    % Colore di default (es. Ciano e Verde acqua) se la squadra non esiste
                    face_col = [0, 1, 1];       
                    edge_col = [0, 0.5, 0.5];
            end
        end