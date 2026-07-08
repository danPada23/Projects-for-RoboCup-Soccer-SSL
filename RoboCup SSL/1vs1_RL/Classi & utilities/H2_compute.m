function K = H2_compute(A,B1,B2,C2,D22)

%Dimensions
n = size(A, 1);         % Numero di stati (n=4 per l'uniciclo)
m = size(B1, 2);        % Numero di ingressi di controllo (m=2)
q = size(C2, 1);        % Numero di uscite obiettivo (q=4)

% LMI definition (Yalmip)
X     = sdpvar(n);
Y     = sdpvar(m,n);
Q     = sdpvar(q,q,'symmetric');
rho   = sdpvar(1);

V1 = A*X + X*A' + B1*Y + Y'*B1' + B2*B2' <= 0;
V2 = ([Q              , (C2*X + D22*Y);
      (C2*X + D22*Y)',  X] ) >= 0;
V3 = trace(Q) <= rho;
V4 = X >= 0;
V5 = Q >= 0;
V6 = rho >= 0;
V  = V1+V2+V3+V4+V5+V6;

opts=sdpsettings;
opts.solver='sedumi';
yalmipdiagnostics=optimize(V,rho,opts);

X_sol   = double(X);
Y_sol   = double(Y);
rho_sol = double(rho);

K = Y_sol * inv(X_sol);

end