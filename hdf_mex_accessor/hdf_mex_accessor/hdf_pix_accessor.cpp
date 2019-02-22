#include "hdf_pix_accessor.h"



hdf_pix_accessor::hdf_pix_accessor()
{
	this->file_handle = -1;
	this->pix_group_id = -1;

	this->pix_dataset = -1;
	this->pix_data_id = -1;

	this->file_space_id = -1;

	this->io_mem_space = -1;


}
void tester(size_t &value ) {
	value++;
}

/* Simple initializer providing access to pixel data
 Assumes that all files and all groups are present.

Opens the file and pixels group for read access
The destructor should close all files and groups
Inpits:
in_filename          -- the name of nxsqw file to read
in_pixels_group_name -- full name of the pixels group within the hdf file.
*/
void hdf_pix_accessor::init(const std::string &in_filename, const std::string &in_pixels_group_name)
{
	this->filename = in_filename;
	this->pix_group_name = in_pixels_group_name;

	this->pix_data_id = H5Tcopy(H5T_NATIVE_FLOAT);

	this->file_handle = H5Fopen(in_filename.c_str(), H5F_ACC_RDONLY, H5P_DEFAULT);
	if (this->file_handle < 0) {
		mexErrMsgIdAndTxt("HDF_MEX_ACCESSOR:runtime_error", "can not open input file");
	}
	this->pix_group_id = H5Gopen(this->file_handle, in_pixels_group_name.c_str(), H5P_DEFAULT);
	if (this->pix_group_id < 0) {
		mexErrMsgIdAndTxt("HDF_MEX_ACCESSOR:runtime_error", "can not open pixels group");
	}
	this->pix_dataset = H5Dopen(this->pix_group_id, "pixels", H5P_DEFAULT);
	if (this->pix_dataset < 0) {
		mexErrMsgIdAndTxt("HDF_MEX_ACCESSOR:runtime_error", "can not open pixels dataset");
	}

	//
	this->file_space_id = H5Dget_space(this->pix_dataset);
	if (this->file_space_id) {
		mexErrMsgIdAndTxt("HDF_MEX_ACCESSOR:runtime_error", "can not retrieve pixels dataspace on file");
	}
	int n_dims = H5Sget_simple_extent_ndims(this->file_space_id);
	if (n_dims != 2) {
		std::ostringstream  err_ss("pixels array dimensions should be equal to 2 but actually is: ");
		err_ss << n_dims;
		std::string err = err_ss.str();
		mexErrMsgIdAndTxt("HDF_MEX_ACCESSOR:runtime_error", err.c_str());
	}

	hsize_t dims[2], max_dims[2];
	int ndims = H5Sget_simple_extent_dims(this->file_space_id, dims, max_dims);
	if (ndims < 0) {
		mexErrMsgIdAndTxt("HDF_MEX_ACCESSOR:runtime_error", "can not retrieve pixels array dimensions");
	}

	this->max_num_pixels_ = max_dims[0];
	if (max_dims[1] != 9) {
		std::ostringstream  err_ss("'wrong size of pixel dataset. dimenison 1 has to be 9 but is: ");
		err_ss << max_dims[1];
		std::string err = err_ss.str();
		mexErrMsgIdAndTxt("HDF_MEX_ACCESSOR:runtime_error", err.c_str());
	}

	hid_t dcpl_id = H5Dget_create_plist(this->pix_dataset);
	hsize_t chunk_size[2];
	n_dims = H5Pget_chunk(dcpl_id, 2, chunk_size);
	if (n_dims != 2) {
		std::ostringstream  err_ss("pixels array chunk dimensions should be equal to 2 but actually is: ");
		err_ss << n_dims;
		std::string err = err_ss.str();
		mexErrMsgIdAndTxt("HDF_MEX_ACCESSOR:runtime_error", err.c_str());
	}

	this->io_chunk_size_ = chunk_size[0];
	const hsize_t block_dims[2] = { this->io_chunk_size_ , 9 };

	this->io_mem_space = H5Screate_simple(2, block_dims, block_dims);

	H5Dclose(dcpl_id);

}
//
void hdf_pix_accessor::close_pix_dataset() {

	if (this->file_space_id != -1) {
		H5Sclose(this->file_space_id);
		this->file_space_id = -1;
	}

	if (this->pix_dataset != -1) {
		H5Dclose(this->pix_dataset);
		this->pix_dataset = -1;
	}


}
/*  read pixel information specified by pixels starting position
*	and the sizes of the pixels blocks
*
*  does not work for overlapping pixels regions so pixels regions should not be overlapping
*
*/
hsize_t hdf_pix_accessor::read_pixels(uint64_t **block_pos, uint64_t **block_sizes,
	 size_t n_blocks_in_blocks,size_t &start_pos, float *const pix_buffer, size_t pix_buf_size) {

	//hsize_t n_hs_blocks[2]    = { 1,1 };
	hsize_t block_start[2]    = { 0,0 };
	hsize_t pix_chunk_size[2] = { 0,9 };
	hsize_t read_pos(start_pos);

	tester(*block_pos[2]);

	size_t n_blocks = n_blocks_in_blocks - start_pos;
	size_t npix_to_read = this->set_block_params(*block_sizes[start_pos], *block_sizes[start_pos], pix_buf_size, block_start, pix_chunk_size,read_pos);

	herr_t err = H5Sselect_hyperslab(this->file_space_id, H5S_SELECT_SET, block_start, NULL, pix_chunk_size, NULL);
	if (err < 0) {
		mexErrMsgIdAndTxt("HDF_MEX_ACCESSOR:runtime_error", "Can not select hyperslab while selecting pixels");
	}
	size_t n_prov_pix(npix_to_read);
	size_t cur_pos(start_pos);
	for (size_t i = 1; i < n_blocks; ++i) {
		cur_pos = start_pos + i;
		n_prov_pix += *block_sizes[cur_pos];
		if (n_prov_pix > pix_buf_size)break;

		size_t n_selected = this->set_block_params(*block_pos[cur_pos],*block_sizes[cur_pos], pix_buf_size, block_start, pix_chunk_size, read_pos);
		if (n_selected < 1)break;

		err = H5Sselect_hyperslab(this->file_space_id, H5S_SELECT_OR, block_start, NULL, pix_chunk_size, NULL);
		if (err < 0) {
			mexErrMsgIdAndTxt("HDF_MEX_ACCESSOR:runtime_error", "Can not select hyperslab while selecting pixels");
		}
		npix_to_read = npix_to_read+ n_selected;
	}
	if (this->io_chunk_size_ != npix_to_read) {
		H5Sset_extent_simple(this->io_mem_space, 2, pix_chunk_size, pix_chunk_size);
		this->io_chunk_size_ = npix_to_read;
	}
	err = H5Dread(this->pix_dataset, this->pix_data_id, this->io_mem_space, this->file_space_id, H5P_DEFAULT, pix_buffer);
	if (err < 0) {
		mexErrMsgIdAndTxt("HDF_MEX_ACCESSOR:runtime_error", "Error reading pixels");
	}
	return read_pos;

}
size_t hdf_pix_accessor::set_block_params(uint64_t &block_pos, uint64_t &block_size, size_t pix_buf_size,
	hsize_t *const block_start, hsize_t *const pix_chunk_size, hsize_t &read_pos) {

	bool advance(true);

	if (block_size > pix_buf_size) {
		block_size = pix_buf_size;
		advance = false;
	}

	if (block_pos + block_size > this->max_num_pixels_) {
		block_size = this->max_num_pixels_ - block_pos;
		block_pos  = this->max_num_pixels_;
		advance = false;
	}

	block_start[0] = block_pos;
	pix_chunk_size[0] = block_size;

	if (advance) read_pos++;

	return block_size;
}
/*
if numel(start_pos) == 1
	block_start = [start_pos - 1, 0];
	pix_chunk_size = [n_pix, 9];

if obj.io_chunk_size_ ~= n_pix
H5S.set_extent_simple(obj.io_mem_space_, 2, pix_chunk_size, pix_chunk_size);
obj.io_chunk_size_ = n_pix;
end


H5S.select_hyperslab(obj.file_space_id_, 'H5S_SELECT_SET', block_start, [], [], pix_chunk_size);
pixels = H5D.read(obj.pix_dataset_, 'H5ML_DEFAULT', obj.io_mem_space_, obj.file_space_id_, 'H5P_DEFAULT');

start_pos = [];
else
if numel(n_pix) ~= numel(start_pos)
if numel(n_pix) == 1
npix = ones(numel(start_pos), 1)*n_pix;
else
error('HDF_PIX_GROUP:invalid_argument', ...
	'number of pix blocks (%d) has to be equal to the number of pix positions (%d) or be equal to 1', ...
	numel(n_pix), numel(start_post));
end
else
if size(n_pix, 2) ~= 1
npix = n_pix';
else
npix = n_pix;
end
end
if size(start_pos, 2) ~= 1
block_start = start_pos'-1;
else
block_start = start_pos - 1;
end

n_blocks = numel(start_pos);
block_start = [block_start, zeros(n_blocks, 1)];
pix_sizes = ones(n_blocks, 1) * 9;
pix_chunk_size = [npix, pix_sizes];

H5S.select_hyperslab(obj.file_space_id_, 'H5S_SELECT_SET', block_start(1, :), [], [], pix_chunk_size(1, :));

if npix(1) + npix(2) > obj.chunk_size_
selected_size = npix(1);
last_block2select = 1;
else
npix_tot = cumsum(npix);
last_block2select = find(npix_tot > obj.chunk_size_, 1) - 1;
if isempty(last_block2select)
last_block2select = n_blocks;
%elseif last_block2select == 1 this is covered by npix(1) + npix(2) > obj.chunk_size_
end
chunk_ind = 2:last_block2select;

arrayfun(@(ind)H5S.select_hyperslab(obj.file_space_id_, 'H5S_SELECT_OR', block_start(ind, :), [], [], pix_chunk_size(ind, :)), chunk_ind);
selected_size = npix_tot(last_block2select);
end

%                 selected_size = pix_chunk_size(1, 1);
%                 n_blocks_selected = 1;
%                 if selected_size < obj.cache_size
	%                     for i = 2:n_blocks
	% next_size = selected_size + pix_chunk_size(i, 1);
%                         if selected_size > obj.chunk_size_
%                             break;
%                         end
%                         selected_size = next_size;
%                         H5S.select_hyperslab(obj.file_space_id_, 'H5S_SELECT_OR', block_start(i, :), [], [], pix_chunk_size(i, :));
%                         n_blocks_selected = n_blocks_selected + 1;
%                     end
%                 end
start_pos = start_pos(last_block2select + 1:end);
if numel(n_pix) > 1
n_pix = n_pix(last_block2select + 1:end);
end

mem_block_size = [selected_size, 9];
if obj.io_chunk_size_ ~= selected_size
H5S.set_extent_simple(obj.io_mem_space_, 2, mem_block_size, mem_block_size);
obj.io_chunk_size_ = selected_size;
end

pixels = H5D.read(obj.pix_dataset_, 'H5ML_DEFAULT', obj.io_mem_space_, obj.file_space_id_, 'H5P_DEFAULT');


end
end
*/
hdf_pix_accessor::~hdf_pix_accessor()
{
	if (this->io_mem_space != -1) {
		H5Sclose(this->io_mem_space);
	}
	if (this->pix_data_id != -1) {
		H5Tclose(this->pix_data_id);
	}
	this->close_pix_dataset();

	if (this->pix_group_id != -1) {
		H5Gclose(this->pix_group_id);
	}
	if (this->file_handle != -1) {
		H5Fclose(this->file_handle);
	}

}


