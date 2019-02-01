function eval_write_speed

block_size = [16,32,64,128,256,512,1024,2048,4096,8192,16384,32768,65536,131072,262144,524288];
N_att = 10;

for n_block = 1:numel(block_size)
    
    nblocks = floor(block_size(end)*10/block_size(n_block));
    
    t0 = tic;
    for i = 1:N_att
        bin_writer(block_size(n_block),nblocks ,2);
    end
    t1=toc(t0);
    fprintf('Block size: %8d :bin speed: %6.1f(MPix/sec): hdf speed:',...
        block_size(n_block),(block_size(n_block)*N_att*nblocks/(1024*1024))/t1);
    t0 = tic;
    for i = 1:10
        hdf_writer(block_size(n_block),nblocks ,2);
    end
    t2=toc(t0);
    
    fprintf('  %6.1f(MPix/sec)\n',(block_size(n_block)*N_att*nblocks/(1024*1024))/t2 );
    
end