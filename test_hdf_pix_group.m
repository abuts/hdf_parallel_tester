classdef test_hdf_pix_group < TestCase
    %Unit tests to validate hdf_pix_group class
    %
    
    properties
    end
    
    methods
        function obj = test_hdf_pix_group(varargin)
            if nargin == 0
                class_name = 'test_hdf_pix_group';
            else
                class_name = varargin{1};
            end
            obj = obj@TestCase(class_name);
        end
        function close_fid(obj,fid,file_h,group_id)
            H5G.close(group_id);
            if ~isempty(file_h)
                H5G.close(fid);
                H5F.close(file_h);
            else
                H5F.close(fid);
            end
        end
        
        
        function test_read_write(obj)
            f_name = [tempname,'.nxsqw'];
            [fid,group_id,file_h,data_version] = open_or_create_nxsqw_head(f_name);
            clob1 = onCleanup(@()close_fid(obj,fid,file_h,group_id));
            clob2 = onCleanup(@()delete(f_name));
            
            arr_size = 100000;
            pix_writer = hdf_pix_group(group_id,arr_size,16*1024);
            assertTrue(exist(f_name,'file')==2);
            pix_alloc_size = pix_writer.max_num_pixels;
            chunk_size     = pix_writer.chunk_size;
            assertEqual(chunk_size,16*1024);
            assertTrue(pix_alloc_size >= arr_size);
            
            data = ones(9,100);
            pos = [2,arr_size/2,arr_size-size(data,2)];
            pix_writer.write_pixels(pos(1),data);
            
            pix_writer.write_pixels(pos(2),2*data);
            
            pix_writer.write_pixels(pos(3),3*data);
            clear pix_writer;
            
            
            pix_reader = hdf_pix_group(group_id);
            assertEqual(chunk_size,pix_reader.chunk_size);
            assertEqual(pix_alloc_size,pix_reader.max_num_pixels);
            
            
            pix1 = pix_reader.read_pixels(pos(1),size(data,2));
            pix2 = pix_reader.read_pixels(pos(2),size(data,2));
            pix3 = pix_reader.read_pixels(pos(3),size(data,2));
            
            assertEqual(single(data),pix1);
            assertEqual(single(2*data),pix2);
            assertEqual(single(3*data),pix3);
            
            clear pix_reader;
            clear clob1
            
            [fid,group_id,file_h,rec_version] = open_or_create_nxsqw_head(f_name);
            clob1 = onCleanup(@()close_fid(obj,fid,file_h,group_id));
            
            assertEqual(data_version,rec_version);
            
            pix_reader = hdf_pix_group(group_id);
            pix3 = pix_reader.read_pixels(pos(3),size(data,2));
            pix2 = pix_reader.read_pixels(pos(2),size(data,2));
            pix1 = pix_reader.read_pixels(pos(1),size(data,2));
            
            
            
            assertEqual(single(data),pix1);
            assertEqual(single(2*data),pix2);
            assertEqual(single(3*data),pix3);
            
            clear pix_reader;
            
            clear clob1;
            clear clob2;
        end
        function test_missing_file(obj)
            f_name = [tempname,'.nxsqw'];
            
            [fid,group_id,file_h] = open_or_create_nxsqw_head(f_name);
            clob1 = onCleanup(@()close_fid(obj,fid,file_h,group_id));
            clob2 = onCleanup(@()delete(f_name));
            
            f_missing = @()hdf_pix_group(group_id);
            assertExceptionThrown(f_missing,'HDF_PIX_GROUP:runtime_error')
            
        end
        function test_multiblock_read(obj)
            f_name = [tempname,'.nxsqw'];
            
            [fid,group_id,file_h] = open_or_create_nxsqw_head(f_name);
            clob1 = onCleanup(@()close_fid(obj,fid,file_h,group_id));
            clob2 = onCleanup(@()delete(f_name));
            
            arr_size = 100000;
            pix_acc = hdf_pix_group(group_id,arr_size,1024);
            assertTrue(exist(f_name,'file')==2);
            
            data = repmat(1:arr_size,9,1);
            pix_acc.write_pixels(1,data);
            
            pos = [10,100,400];
            npix = 10;
            [pix,pos,npix] = pix_acc.read_pixels(pos,npix);
            assertEqual(pix(2,1:10),single(10:19));
            assertEqual(pix(9,11:20),single(100:109));
            assertEqual(pix(1,21:30),single(400:409));
            assertTrue(isempty(pos));
            assertEqual(npix,10);
            
            pos = [10,2000,5000];
            npix =[1024,2048,1000];
            [pix,pos,npix] = pix_acc.read_pixels(pos,npix);
            
            assertEqual(pix(3,1:1024),single(10:1033));
            assertEqual(numel(pos),2);
            assertEqual(numel(npix),2);
            
            [pix,pos,npix] = pix_acc.read_pixels(pos,npix);
            assertEqual(pix(1,1:2048),single(2000:(1999+2048)));
            assertEqual(numel(pos),1);
            assertEqual(numel(npix),1);
            
            [pix,pos,npix] = pix_acc.read_pixels(pos,npix);
            assertEqual(pix(1,1:1000),single(5000:(4999+1000)));
            assertTrue(isempty(pos));
            assertEqual(npix,1000);
            
            
            % single read operation as total size is smaller than the block
            % size
            pos = [10,1000,2000];
            npix =[128,256,256];
            [pix,pos,npix] = pix_acc.read_pixels(pos,npix);
            assertEqual(pix(1,385:(384+256)),single(2000:(1999+256)));
            asserttTrue(isempty(pos));
            asserttTrue(isempty(npix));
            
            clear pix_acc;
            clear clob1;
            clear clob2;
            
        end
        
        function  test_mex_reader(obj)
            if isempty(which('hdf_mex_reader'))
                warning('TEST_MEX_READER:runtime_error',...
                    'the hdf mex reader was not found in the Matlab path');
                return
            end
            % use when mex code debuging only
            %clob0 = onCleanup(@()clear('mex'));
            
            f_name = [tempname,'.nxsqw'];
            
            [fid,group_id,file_h] = open_or_create_nxsqw_head(f_name);
            clob1 = onCleanup(@()delete(f_name));
            clob2 = onCleanup(@()close_fid(obj,fid,file_h,group_id));
            
            
            arr_size = 100000;
            pix_acc = hdf_pix_group(group_id,arr_size,1024);
            assertTrue(exist(f_name,'file')==2);
            clob3 = onCleanup(@()delete(pix_acc));
            
            data = repmat(1:arr_size,9,1);
            for i=1:9
                data(i,:) = data(i,:)*i;
            end
            pix_acc.write_pixels(1,data);
            
            % check mex file is callable
            rev = hdf_mex_reader();
            assertTrue(~isempty(rev));
            
            [pix_array,next_pix_pos,pix_block_sizes]=hdf_mex_reader('close','close');
            assertTrue(isempty(pix_array))
            assertTrue(isempty(next_pix_pos));
            assertTrue(isempty(pix_block_sizes));
            
            [root_nx_path,~,data_structure] = find_root_nexus_dir(f_name,"NXSQW");
            group_name = data_structure.GroupHierarchy.Groups.Groups(1).Name;
            
            ferr = @()hdf_mex_reader(f_name,group_name);
            assertExceptionThrown(ferr,'HDF_MEX_ACCESS:invalid_argument');
            
            % the mex modifies the array contents in memory on the second run 
            pos = [10,2000,5000];
            npix =[1024,1024,1000];
            [pix_array,pos,npix]=hdf_mex_reader(f_name,group_name,pos,npix,2048);
            
            assertVectorsAlmostEqual(size(pix_array),[9,2048]);
            assertEqual(numel(pos),1);
            assertEqual(numel(npix),1);
            assertEqual(pos(1),5000);
            assertEqual(npix(1),1000);
            assertElementsAlmostEqual(pix_array(:,1:1024),data(:,10:1033));
            assertElementsAlmostEqual(pix_array(:,1025:2048),data(:,2000:2000+1023));
            
            [pix_array,pos,npix]=hdf_mex_reader(f_name,group_name,pos,npix,2048);
            
            assertVectorsAlmostEqual(size(pix_array),[9,1000]);
            assertTrue(isempty(pos));
            assertTrue(isempty(npix));
            assertElementsAlmostEqual(pix_array(:,1:1000),data(:,5000:5000+999));
            
            pos = [10,2000,5000];
            npix =[1024,1024,1000];
            [pix_array,pos,npix]=hdf_mex_reader(f_name,group_name,pos,npix,2000);
            
            assertVectorsAlmostEqual(size(pix_array),[9,2000]);
            assertEqual(numel(pos),2);
            assertEqual(numel(npix),2);
            assertVectorsAlmostEqual(pos,[2977;5000]);
            assertVectorsAlmostEqual(npix,[48;1000]);
            assertElementsAlmostEqual(pix_array(:,1:1024),data(:,10:1033));
            assertElementsAlmostEqual(pix_array(:,1025:2000),data(:,2000:2000+975))

            [pix_array,pos,npix]=hdf_mex_reader(f_name,group_name,pos,npix,2000);            
            assertVectorsAlmostEqual(size(pix_array),[9,1048]);            
            assertTrue(isempty(pos));
            assertTrue(isempty(npix));
            assertElementsAlmostEqual(pix_array(:,1:48),data(:,2976:(2976+47)));
            assertElementsAlmostEqual(pix_array(:,49:1048),data(:,5000:(5000+999)))
            
            clear pos;
            clear npix;
            clear clob3;
            clear clob2;
            clear clob1;
            
        end
    end
end

