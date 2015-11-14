%*************************************************
% Simulation Parameters
%*************************************************
close all;
clc;
clear all;

%******************
% Source Parameters
%******************
lam0 = 2 * 10^-2;   %Free Space Wavelength
ginc = [0;0;1];     %Incident wave vector
EP = [0;1;0];       %Source Polarization
theta = 0;
phi = 0;
pte = 1;
ptm = 0;


%***********************
% Trans / Ref Parameters
%***********************
urR = 1.0;  %Permeability of Reflection Region
erR = 2.0;  %Permittivity of Reflection Region
urT = 1.0;  %Permeability of Transmission Region
erT = 9.0;  %Permittivity of Transmission Region

%******************
% Device Parameters
%******************
urd = 1.0;  %Permeability of device
erd = 6.0;  %Permittivity of device

%*****************
% Layer Parameters
%*****************
Lx = 17.5 * 10^(-3);  %period in x-direction
Ly = 15 * 10^(-3);    %period in y-direction
d1 = 5 * 10^(-3);     %thickness of layer 1
d2 = 3 * 10^(-3);     %thickness of layer 2
w = 0.8 * Ly;

%****************
% RCWA Parameters
%****************
Nx = 512;                 %x points in real-space grid
Ny = round(Nx * Ly / Lx); %y points in real-space grid
Nharmonics = 3;           %number of spatial harmonics for x, y

%***********************************************************************
% Build Device on grid
%***********************************************************************
dx = Lx / Nx;       %grid resolution in x
dy = Ly / Ny;       %grid resolution in y
xa = [0:Nx-1] * dx; %x axis array
xa = xa - mean(xa); %center x array at 0
ya = [0:Ny-1] * dy; %y axis array
ya = ya - mean(ya); %center y array at 0

%Initialize Layers to device
UR = urd * ones(Nx,Ny,2);
ER = erd * ones(Nx,Ny,2);
L = [d1, d2];

%Build Triangle (Layer 1)
h = 0.5 * sqrt(3) * w;
ny = round(h/dy);
ny1 = round((Ny-ny)/2);
ny2 = ny1+ny - 1;

for ny = ny1:ny2
  f = (ny - ny1) / (ny2 - ny1);
  nx = round(f*w/Lx * Nx);
  nx1 = 1 + floor((Nx - nx)/2);
  nx2 = nx1 + nx;
  ER(nx1:nx2,ny,1) = erR;
end

for layer = 1:length(L)
    ERC(:,:,layer) = convmat(ER(:,:,layer),Nharmonics,Nharmonics);
    URC(:,:,layer) = convmat(UR(:,:,layer),Nharmonics,Nharmonics);
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Calculate Kx, Ky, Kz Matrices 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
ninc = sqrt(erR *urR);
kinc = ninc.*[sind(theta)*cosd(phi),sind(theta)*sind(phi),cosd(theta)];
k0 = 2*pi / lam0;

m = 1;
n = 1;
pqm = 1;
pqn = 1;
pq_bound = floor(Nharmonics/2);
pq = -pq_bound:pq_bound;

while(m <= Nharmonics^2)
  kx(m) = kinc(1) - pq(pqm)*(2*pi) / (k0*Lx); 
  n = 1;
  pqn = 1;
  while(n <= Nharmonics^2)
    ky(n) = kinc(2) - pq(pqn)*(2*pi) / (k0*Ly);
    kz_ref(m,n) = conj(sqrt(urR*erR - kx(m)^2 - ky(n)^2));
    kz_trn(m,n) = conj(sqrt(urT*erT - kx(m)^2 - ky(n)^2)); 
    if(mod(n,Nharmonics) == 0)
        pqn = pqn+1;
    end
    n=n+1;
  end
  if(mod(pqm,Nharmonics) == 0)
    pqm = 0;
  end
  m = m+1;
  pqm = pqm+1;
end

Kx = diag(kx(:));
Ky = diag(ky(:));
Kz_ref = diag(diag(kz_ref(:,:)));
Kz_trn = diag(diag(kz_trn(:,:)));

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%   Free Space Calculation
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
Kz_0 = conj(sqrt(eye(Nharmonics^2) - Kx.^2 - Ky.^2));

Q0 = zeros(2*Nharmonics^2,2*Nharmonics^2);
Q0(1:Nharmonics^2,1:Nharmonics^2) = Kx * Ky;
Q0(Nharmonics^2+1:end,Nharmonics^2+1:end) = -Kx * Ky;
Q0(1:Nharmonics^2,Nharmonics^2+1:end) = eye(Nharmonics^2) - Kx.^2;
Q0(Nharmonics^2+1:end,1:Nharmonics^2) = Ky.^2 - eye(Nharmonics^2);

W0 = eye(2*Nharmonics^2);

LAM0 = zeros(2*Nharmonics^2,2*Nharmonics^2);
LAM0(1:Nharmonics^2,1:Nharmonics^2) = 1j.*Kz_0;
LAM0(Nharmonics^2+1:end,Nharmonics^2+1:end) = 1j.*Kz_0;

V0 = Q0 * inv(LAM0);

SG.S11 = zeros(2*Nharmonics^2,2*Nharmonics^2);
SG.S21 = eye(2*Nharmonics^2);
SG.S12 = eye(2*Nharmonics^2);
SG.S22 = zeros(2*Nharmonics^2,2*Nharmonics^2);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%   Reflection Side Calculation
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
Qref = zeros(2*Nharmonics^2,2*Nharmonics^2);
Qref(1:Nharmonics^2,1:Nharmonics^2) = Kx * Ky;
Qref(1:Nharmonics^2,Nharmonics^2+1:end) = urR*erR * eye(Nharmonics^2) - Kx.^2;
Qref(Nharmonics^2+1:end,1:Nharmonics^2) = Ky.^2 - urR*erR * eye(Nharmonics^2);
Qref(Nharmonics^2+1:end,Nharmonics^2+1:end) = -Ky * Kx;
Qref = Qref ./ urR;

Wref = eye(2*Nharmonics^2);

LAMref = zeros(2*Nharmonics^2,2*Nharmonics^2);
LAMref(1:Nharmonics^2,1:Nharmonics^2) = 1j.*Kz_ref;
LAMref(Nharmonics^2+1:end,Nharmonics^2+1:end) = 1j.*Kz_ref;

Vref = Qref * inv(LAMref);

Aref = inv(W0)*Wref + inv(V0)*Vref;
Bref = inv(W0)*Wref - inv(V0)*Vref;

Sref.S11 = -inv(Aref)*Bref;
Sref.S12 = 2*inv(Aref);
Sref.S21 = 0.5*(Aref - Bref*inv(Aref)*Bref);
Sref.S22 = Bref*inv(Aref);


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%   Transmission Side Calculation
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
Qtrn = zeros(2*Nharmonics^2,2*Nharmonics^2);
Qtrn(1:Nharmonics^2,1:Nharmonics^2) = Kx * Ky;
Qtrn(1:Nharmonics^2,Nharmonics^2+1:end) = urT*erT * eye(Nharmonics^2) - Kx.^2;
Qtrn(Nharmonics^2+1:end,1:Nharmonics^2) = Ky.^2 - urT*erT * eye(Nharmonics^2);
Qtrn(Nharmonics^2+1:end,Nharmonics^2+1:end) = -Ky * Kx;
Qtrn = Qtrn ./ urT;

Wtrn = eye(2*Nharmonics^2);

LAMtrn = zeros(2*Nharmonics^2,2*Nharmonics^2);
LAMtrn(1:Nharmonics^2,1:Nharmonics^2) = 1j.*Kz_trn;
LAMtrn(Nharmonics^2+1:end,Nharmonics^2+1:end) = 1j.*Kz_trn;

Vtrn = Qtrn * inv(LAMtrn);

Atrn = inv(W0)*Wtrn + inv(V0)*Vtrn;
Btrn = inv(W0)*Wtrn - inv(V0)*Vtrn;

Strn.S11 = Btrn*inv(Atrn);
Strn.S12 = 0.5*(Atrn - Btrn*inv(Atrn)*Btrn);
Strn.S21 = 2*inv(Atrn);
Strn.S22 = -inv(Atrn)*Btrn;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%   Layer Loop Calculation
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
for layer = 1:length(L)
  Pi = zeros(2*Nharmonics^2,2*Nharmonics^2);
  Pi(1:Nharmonics^2,1:Nharmonics^2) = Kx*inv(ERC(:,:,layer))*Ky;
  Pi(Nharmonics^2+1:end,1:Nharmonics^2) = URC(:,:,layer) - Kx*inv(ERC(:,:,layer))*Kx;
  Pi(1:Nharmonics^2,Nharmonics^2+1:end) = Ky*inv(ERC(:,:,layer))*Ky - URC(:,:,layer);
  Pi(Nharmonics^2+1:end,Nharmonics^2+1:end) = -Ky*inv(ERC(:,:,layer))*Kx;

  Qi = zeros(2*Nharmonics^2,2*Nharmonics^2);
  Qi(1:Nharmonics^2,1:Nharmonics^2) = Kx*inv(URC(:,:,layer))*Ky;
  Qi(Nharmonics^2+1:end,1:Nharmonics^2) = ERC(:,:,layer) - Kx*inv(URC(:,:,layer))*Kx;
  Qi(1:Nharmonics^2,Nharmonics^2+1:end) = Ky*inv(URC(:,:,layer))*Ky - ERC(:,:,layer);
  Qi(Nharmonics^2+1:end,Nharmonics^2+1:end) = -Ky*inv(URC(:,:,layer))*Kx;

  [Wi, LAMi] = eig(Pi*Qi);
  LAMi = sqrt(LAMi);
  Vi = Qi*Wi*inv(LAMi);

  Ai = inv(Wi)*W0 + inv(Vi)*V0;
  Bi = inv(Wi)*W0 - inv(Vi)*V0;
  Xi = expm(-LAMi*k0*L(layer));
  
  Si.S11 = inv(Ai - Xi*Bi*inv(Ai)*Xi*Bi) * (Xi*Bi*inv(Ai)*Xi*Ai - Bi);
  Si.S12 = inv(Ai - Xi*Bi*inv(Ai)*Xi*Bi) * Xi*(Ai - Bi*inv(Ai)*Bi);
  Si.S21 = Si.S12;
  Si.S22 = Si.S11;
  
  SG = star(SG,Si);
end

SG = star(Sref,SG);
SG = star(SG,Strn);

























