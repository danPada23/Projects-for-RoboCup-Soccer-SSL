%--Geometria (cerchio difesa)
        function [center, radius] = get_passive_circle(obj)
            center = [obj.x; obj.y];
            radius = obj.R_hex;
        end