function run_job(filesize)
% filesize -- the size of the runfile in Horace pixels
%
cl = gcp('nocreate');
if isempty(cl)
    cl  = parcluster();
end
n_workers  = cl.NumWorkers;
n_files = n_workers;
a_file_size = filesize/n_files;

job = createCommunicatingJob(cl,'Type','SPMD');

block_size = 1024*4;
n_blocks = floor(a_file_size/block_size);
%inputs = cell(1,n_workers);

inputs = {block_size,n_blocks};


createTask(job, @bin_writer, 0,inputs);

t0 = tic;
submit(job);
wait(job)
t_end = toc(t0);
fprintf(' time to write input files with total size %d  in parallel: %f(sec)\n',filesize,t_end);


job = createCommunicatingJob(cl,'Type','SPMD');
createTask(job, @bin_reader, 1,inputs);
t0 = tic;
submit(job);
wait(job)
t_end = toc(t0);
out = fetchOutputs(job);
disp(out);
log = getDebugLog(cl,job);
fprintf(' time to commbine input files with total size %d  in parallel: %f(sec)\n',filesize,t_end);

