mask_name = 'Mask_60Ma_lon1.5-3-358.5_lat-79.5-3-79.5_qz1.8';
saveRestricted = true;
periodic = true;

M = load([mask_name,'.mat']);
mask = M.maskp;

figure(1)
imagesc(mask);
set(gca,'ydir','normal');

l = max(max(mask)); % levels
[m,n] = size(mask);

fprintf('mask has dimensions %d x %d x %d\n', n,m,l);
fprintf('cutting these in half...\n');

mask = round(mask / 2);
M = m/2;
N = n/2;
mask2 = zeros(M,N);

for j = 1:M
  for i = 1:N
	  jrange = (j-1)*2 + 1 : j*2;
	  irange = (i-1)*2 + 1 : i*2;
	  mask2(j,i) = round(sum(sum(mask(jrange, irange)))/4);
  end
end

figure(2)
imagesc(mask2);
set(gca,'ydir','normal');

if (saveRestricted)
  fname = sprintf('%s/coarsened',mask_name);
  maskp = mask2;
  system(['mkdir -p ', mask_name]);
  fprintf(' writing to %s\n', fname);
  save([fname,'.mat'],'maskp')
  transform_mask(fname, periodic);
end
