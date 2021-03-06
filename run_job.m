function run_job(filesize)
% filesize -- the size of the runfile in Horace pixels
%
cl = gcp('nocreate');
if isempty(cl)
    cl  = parcluster();
end
if ~exist('filesize','var')
    filesize = 1024*32*10000;
end
n_workers = 8;
use_hdf = true;
block_size = 1024*32;

if use_hdf 
    disp(' **********  Using hdf IO *******************')
    file_creator = @(x,y)hdf_writer(x,y);
    file_combiner =@(x,y)hdf_communicator(x,y);
    %file_combiner =@(x,y)bin_communicator(x,y);       
else
    disp(' **********  Using binaly IO ****************')    
    file_creator = @(x,y)bin_writer(x,y);    
    file_combiner =@(x,y)bin_communicator(x,y);    
end


cl.NumWorkers = n_workers;
%n_workers  = cl.NumWorkers;
n_files = n_workers-1;
a_file_size = filesize/n_files;

job = createCommunicatingJob(cl,'Type','SPMD','AutoAttachFiles',false);


n_blocks = floor(a_file_size/block_size);
%inputs = cell(1,n_workers);

inputs = {block_size,n_blocks};


createTask(job, file_creator, 2,inputs);
t0 = tic;
submit(job);
wait(job)
t_end = toc(t0);

out = fetchOutputs(job);

disp('time to run workers and job sizes')
disp(out);
for i=1:size(out,1)
    time = out{i,1};
    blc_size = out{i,2};
    if time >0
        fprintf(' io speed for the worker %d: %4.2f(MPix/sec)\n',...
            i,blc_size/(time*1024*1024));
    end
end
out = cell2mat(out);


%run_time = max(out(:,1));
writ_size = sum(out(:,2));

fprintf(' Parallel speed to write %d input files with total size %d  : %f(sec), speed %4.2f(MPix/sec)\n',...
    n_files,writ_size,t_end,writ_size/(t_end*1024*1024));

job = createCommunicatingJob(cl,'Type','SPMD');
createTask(job, file_combiner, 2,inputs);
t0 = tic;
submit(job);
wait(job)
t_end = toc(t0);
out = fetchOutputs(job);
disp('time to run workers and job sizes')
disp(out);
for i=1:size(out,1)
    time = out{i,1};
    blc_size = out{i,2};
    if time >0
        fprintf(' io speed for the worker %d: %4.2f(MPix/sec)\n',...
            i,blc_size/(time*1024*1024));
    end
end

fprintf(' time to commbine input files with total size %d  in parallel: %f(sec), speed %4.2f(MPix/sec)\n',...
    filesize,t_end,filesize/(t_end*1024*1024));

