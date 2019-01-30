function test_write_speed

block_size = [16,32,64,128,256,512,1024,2048,4096,8192,16384,32768,65536,131072,262144,524288];


for n_block = 1:numel(block_size)
    
    nblocks = floor(block_size(end)*10/block_size(n_block));
    
    t0 = tic;
    for i = 1:10
        bin_writer(block_size(n_block),nblocks ,2);
    end
    t1=toc(t0);
    fprintf('Block size: %8d :bin speed: %6.2e(sec/pix): hdf speed:',...
        block_size(n_block),t1/block_size(n_block)/10/nblocks);
    t0 = tic;
    for i = 1:10
        hdf_writer(block_size(n_block),nblocks ,2);
    end
    t2=toc(t0);
    
    fprintf('  %6.2e(sec/pix)\n',t2/block_size(n_block)/10/nblocks );
    
end