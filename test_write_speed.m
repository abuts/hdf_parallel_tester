function test_write_speed

block_size = [8,16,32,64,128,256,512,1024,2048,4096,8192,16384,32768,65536,131072,262144];


for n_block = 1:numel(block_size)
    
    nblocks = floor(block_size(end)*10/block_size(n_block));
    
    t0 = tic;
    for i = 1:10
        %bin_writer(block_size(n_block),nblocks ,2);
        hdf_writer(block_size(n_block),nblocks ,2);
    end
    t1=toc(t0);
    fprintf('Block size: %8d :write speed: %e.2(sec/pix)\n',block_size(n_block),t1/block_size(n_block)/10/nblocks );
    
end