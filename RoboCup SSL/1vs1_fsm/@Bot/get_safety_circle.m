%--Geometria (cerchio di sicurezza)
        function [center, radius] = get_safety_circle(obj)
            center = [obj.x; obj.y];
            radius = obj.b + obj.d;
        end