function d = dist_pt_seg(obj, P, V, W)
            l2 = sum((V - W).^2);
            if l2 == 0
                d = norm(P - V);
                return;
            end
            t = max(0, min(1, dot(P - V, W - V) / l2));
            projection = V + t * (W - V);
            d = norm(P - projection);
        end