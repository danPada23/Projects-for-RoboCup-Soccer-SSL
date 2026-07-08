function reset(obj)
            obj.fsm_state = 0;
            obj.prev_state = -1;
            obj.calcolo_effettuato = false;
            obj.P_A = [];
            obj.P_Beyond = [];
        end