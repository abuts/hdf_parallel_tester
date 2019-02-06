function run_job(filesize)
% filesize -- the size of the runfile in Horace pixels
%
cl = gcp('nocreate');
if isempty(cl)
    cl  = parcluster();
end
if ~exist('filesize','var')
    filesize = 1024*32*10;
end
n_workers  = cl.NumWorkers;
n_files = n_workers-1;
a_file_size = filesize/(n_files-1);

job = createCommunicatingJob(cl,'Type','SPMD');

block_size = 1024*32;
n_blocks = floor(a_file_size/block_size);
%inputs = cell(1,n_workers);

inputs = {block_size,n_blocks};


createTask(job, @bin_writer, 2,inputs);

submit(job);
wait(job)
out = fetchOutputs(job);
out = cell2mat(out);
run_time = max(out(:,1));
writ_size = sum(out(:,2));

fprintf(' Parallel speed to write %d input files with total size %d  : %f(sec)\n',n_files,writ_size,run_time );


job = createCommunicatingJob(cl,'Type','SPMD');
createTask(job, @bin_communicator, 2,inputs);
t0 = tic;
submit(job);
wait(job)
t_end = toc(t0);
out = fetchOutputs(job);
disp(out);
log = getDebugLog(cl,job);
fprintf(' time to commbine input files with total size %d  in parallel: %f(sec)\n',filesize,t_end);

