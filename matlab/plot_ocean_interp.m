function [] = plot_ocean_interp(k,solfile1,solfile2, maskfile1,maskfile2, title_additional, fname_additional)

  fprintf(1,'----------------------------------------------\n')

  %% - DEFINE CONSTANTS - ----------------------------------------------

  udim  = 0.1;                 %[m/s]   Velocity scale
  r0dim = 6.4e6;               %[m]     Radius of Earth
  T0    = 15;                  %[deg C] Reference temperature
  S0    = 35;                  %[psu]   Reference salinity
  RtD   = 180/pi;              %[-]     Radians to degrees

  %% - READ MASK - -----------------------------------------------------

  [n m l la nun xmin xmax ymin ymax hdim x y z xu yv zw landm1] = ...
  readfort44(maskfile1);

  [n m l la nun xmin xmax ymin ymax hdim x y z xu yv zw landm2] = ...
  readfort44(maskfile2);

  landm = (1-k)*landm1 + k*landm2;

  surfm      = landm(2:n+1,2:m+1,l+1);  %Only interior surface points
  landm_int  = landm(2:n+1,2:m+1,2:l+1);
  dx         = (xu(n+1)-xu(1))/n;
  dy         = (yv(m+1)-yv(1))/m;
  dz         = (zw(l+1)-zw(1))/l;

                                % - Create surface landmask image
  srf = [];
  greyness = 1;
  summask = sum(landm_int,3);
  summask = summask / max(max(abs(summask)));
  summask = summask.^3;

  srf(:,:,1) = (1-greyness*((summask')));
  srf(:,:,2) = (1-greyness*((summask')));
  srf(:,:,3) = (1-greyness*((summask')));
  srf(srf<0) = 0;
  srf(srf>1) = 1;

                                % - Deduce grid stretching
  [qz,dfzt,dfzw] = gridstretch(zw);

  %% - READ SOLUTION - -------------------------------------------------
  [lab icp par xl xlp det sig sol1 solup soleig] = ...
  readfort3(la, solfile1);

  [lab icp par xl xlp det sig sol2 solup soleig] = ...
  readfort3(la, solfile2);

  %% - EXTRACT SOLUTION COMPONENTS - -----------------------------------
  [u,v,w,p,T,S] = extractsol((1-k)*sol1+k*sol2);

  %% - INTEGRATIONS - --------------------------------------------------
  % Barotropic streamfunction;
  PSIB = bstream(u*udim,zw*hdim,[y;ymax]*r0dim);

                                % Overturning streamfunction
  PSIG = mstream(v*udim,[x;xmax]*cos(yv(2:m+1))'*r0dim,zw*hdim);
  PSIG = [zeros(m+1,1) PSIG];

  %% - CHECK SALINITY - ------------------------------------------------
  check = checksal(S,x,y,dfzt);
  vol   = sum(sum(1-surfm).*cos(y'))*dx*dy;
  fprintf(1,'Average salinity deficiency of %12.8f psu.\n', -check/vol)

  %% Create Temperature
  % build longitudinal average over non-land cells
  Tl = zeros(m,l);
  Sl = zeros(m,l);

  for k = 1:l
    for j = 1:m
      count = 0;
      for i=1:n
        if landm_int(i,j,k) == 0
          count = count + 1;
          Tl(j,k) = Tl(j,k) + T(i,j,k);
          Sl(j,k) = Sl(j,k) + S(i,j,k);
        else
          S(i,j,k) = 0;
          T(i,j,k) = 0;
        end
      end
      Tl(j,k) = Tl(j,k) / count;
      Sl(j,k) = Sl(j,k) / count;
    end
  end


  %% - PLOT THE RESULTS - ----------------------------------------------
  figure(1)
  img = PSIB(2:end,:)';
  minPSIB = min(PSIB(:))
  maxPSIB = max(PSIB(:))
  image(RtD*x,RtD*(y),srf,'AlphaData',1); set(gca,'ydir','normal');hold on
  contours = linspace(minPSIB,maxPSIB,30);
  contour(RtD*x,RtD*(y),img,contours,'Visible', 'on','linewidth',1); hold off;
                  %imagesc(RtD*x,RtD*(y),img,'AlphaData',1); hold off;
  colorbar
  title(['Barotropic Streamfunction (Sv) ', title_additional]);

  caxis([-40,40]);
  xlabel('Longitude')
  ylabel('Latitude');
  exportfig(['bstream',fname_additional,'.eps'],14,[25,15])


%%%
  figure(2)
  contourf(RtD*([y;ymax+dy/2]-dy/2),zw*hdim',PSIG',30);
  colorbar
  cmin = min(min(PSIG(:,1:9)))
  cmax = max(max(PSIG(:,1:9)))
  title(['MOC (Sv) ',title_additional])
  xlabel('latitude')
  ylabel('depth (m)')
  exportfig(['mstream',fname_additional,'.eps'],14,[25,15])

  return

  %% -------------------------------------------------------
  figure(3)
  Tsurf = T(:,:,l);
  minT = T0+min(min(Tsurf));
  maxT = T0+max(max(Tsurf));

  img  = T0 + Tsurf';
  contourf(RtD*x,RtD*(y),img,20,'Visible', 'off'); hold on;
  set(gca,'color',[0.65,0.65,0.65]);
                    %image(RtD*x,RtD*(y),srf,'AlphaData',0.5); hold on
  contours = linspace(minT,maxT,20);
  imagesc(RtD*x,RtD*(y),img);
                                %imagesc(RtD*x,RtD*(y),img)
                                %set(gca,'ydir','normal');
  hold off

  colorbar
  title('Surface Temperature', 'interpreter', 'none');
  xlabel('Longitude');
  ylabel('Latitude');

  exportfig('sst.eps',10,[50,25])

  %% -------------------------------------------------------
  figure(4)
  contourf(RtD*yv(1:end-1),z*hdim,Tl'+T0,15);
                              %imagesc(RtD*yv(1:end-1),z*hdim,Tp'+T0);
                              %set(gca,'ydir','normal');
                              %pcolor(RtD*yv(1:end-1),z*hdim,Tp'+T0);
  colorbar
  title('Temperature')
  xlabel('Latitude')
  ylabel('z (m)')
  exportfig('isothermals.eps',10,[20,7])

  %%
  figure(6)
  contourf(RtD*yv(1:end-1),z*hdim,Sl'+S0,15);
                               %imagesc(Sp'+S0);
                               %set(gca,'ydir','normal')
                               %pcolor(RtD*yv(1:end-1),z*hdim,Sp'+S0);
  colorbar
  title('Isohalines')
  xlabel('Latitude')
  ylabel('z (m)')

  exportfig('isohalines.eps',10,[20,7])

  %%-----------------------------------------------------------------------------
  figure(7)
  Ssurf = S(:,:,l);
  minS = S0+min(min(Ssurf));
  maxS = S0+max(max(Ssurf));
  for j = 1:m
    for i = 1:n
      if surfm(i,j) == 1
        Ssurf(i,j) = -999;
      end
    end
  end

  img  = S0 + Ssurf';
  contourf(RtD*x,RtD*(y),img,20,'Visible', 'off'); hold on;
  set(gca,'color',[0.65,0.65,0.65]);
  image(RtD*x,RtD*(y),srf,'AlphaData',0.5); hold on
  contours = linspace(minS,maxS,40);
  contourf(RtD*x,RtD*(y),img,contours,'Visible', 'on','linewidth',1); hold off

                                %imagesc(RtD*x,RtD*(y),img);
  set(gca,'ydir','normal');
  grid on
                                %caxis([minS,maxS]);
  colorbar
  title('Surface Salinity', 'interpreter', 'none');
  xlabel('Longitude');
  ylabel('Latitude');


  exportfig('sss.eps',10,[50,25])

end
