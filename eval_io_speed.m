function eval_io_speed

block_size = [32,64,128,256,512,1024,2048,4096,8192,16384,32768,65536,131072,262144,524288];
N_att = 1;
minN_blocks = 100;
disable_binary = false;
for n_block = 1:numel(block_size)
    
    nblocks = floor(block_size(end)*minN_blocks/block_size(n_block));
    if disable_binary
        fprintf('Block size: %8d :Speed(MPix/sec) ',block_size(n_block));
        
    else
        t1 =0 ;
        tot_size = 0;
        for i = 1:N_att
            [tr,wr_sz]=bin_writer(block_size(n_block),nblocks ,2);
            t1=t1+tr;
            tot_size = tot_size+wr_sz;
        end
        
        
        fprintf('Block size: %8d :Speed(MPix/sec) bin Write: %4.1f:',...
            block_size(n_block),(tot_size/(1024*1024))/t1);
        
        file_size = nblocks*block_size(n_block);
        t1=0;
        tot_size = 0;
        for i=1:N_att
            [tr,read_sz]=random_bin_read(file_size,block_size(n_block),floor(nblocks/8),2);
            t1 = t1+tr;
            tot_size = tot_size+read_sz;
        end
        fprintf(' Read: %4.1f:',(tot_size/t1/(1024*1024)));
        t0 = tic;
        for i = 1:N_att
            hdf_writer(block_size(n_block),nblocks ,2);
        end
    end
    t2=toc(t0);
    fprintf(' HDF Write: %4.1f:',(block_size(n_block)*N_att*nblocks/(1024*1024))/t2 );
    %
    t2= 0;
    tot_size = 0;
    for i=1:N_att
        [tr,read_sz]=random_hdf_read(file_size,block_size(n_block),floor(nblocks/8),2);
        t2 = t2+tr;
        tot_size = tot_size+read_sz;
    end
    
    fprintf(' Read:  %4.1f\n',(tot_size/t2/(1024*1024)) );
end