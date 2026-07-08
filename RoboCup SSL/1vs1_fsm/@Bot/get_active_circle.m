%--Geometria (cerchio attacco)
        function [center, radius] = get_active_circle(obj)
            center = [obj.x + obj.b * cos(obj.theta); 
                      obj.y + obj.b * sin(obj.theta)];
            radius = obj.b;
        end