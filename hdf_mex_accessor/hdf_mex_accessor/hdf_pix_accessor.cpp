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
void tester(double &value) {
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
	if (this->file_space_id < 0) {
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
hsize_t hdf_pix_accessor::read_pixels(double *const block_pos, double *const block_sizes,
	size_t n_blocks, size_t &first_block_non_read, float *const pix_buffer, size_t pix_buf_size) {

	//hsize_t n_hs_blocks[2]    = { 1,1 };
	hsize_t block_start[2] = { 0,0 };
	hsize_t pix_chunk_size[2] = { 0,9 };
	first_block_non_read = 0;
	hsize_t n_pix_to_read(0);


	bool selection_completed = this->set_block_params(block_pos[0], block_sizes[0],
		n_pix_to_read, pix_buf_size,
		block_start, pix_chunk_size, first_block_non_read);

	herr_t err = H5Sselect_hyperslab(this->file_space_id, H5S_SELECT_SET, block_start, NULL, pix_chunk_size, NULL);
	if (err < 0) {
		mexErrMsgIdAndTxt("HDF_MEX_ACCESSOR:runtime_error", "Can not select hyperslab while selecting pixels");
	}
	if (!selection_completed) {
		for (size_t i = 1; i < n_blocks; ++i) {

			bool selection_completed = this->set_block_params(block_pos[i], block_sizes[i],
				n_pix_to_read, pix_buf_size,
				block_start, pix_chunk_size, first_block_non_read);

			err = H5Sselect_hyperslab(this->file_space_id, H5S_SELECT_OR, block_start, NULL, pix_chunk_size, NULL);
			if (err < 0) {
				mexErrMsgIdAndTxt("HDF_MEX_ACCESSOR:runtime_error", "Can not select hyperslab while selecting pixels");
			}
			if (selection_completed)break;
		}
	}
	if (this->io_chunk_size_ != n_pix_to_read) {
		hsize_t mem_chunk_size[2] = { n_pix_to_read,9 };
		err = H5Sset_extent_simple(this->io_mem_space, 2, mem_chunk_size, mem_chunk_size);
		if (err < 0)
			mexErrMsgIdAndTxt("HDF_MEX_ACCESSOR:runtime_error", "Can not extend memory dataspace to load pixels");
		this->io_chunk_size_ = n_pix_to_read;
	}
	err = H5Dread(this->pix_dataset, this->pix_data_id, this->io_mem_space, this->file_space_id, H5P_DEFAULT, pix_buffer);
	if (err < 0)
		mexErrMsgIdAndTxt("HDF_MEX_ACCESSOR:runtime_error", "Error reading pixels");

	return n_pix_to_read;

}
/* generate parameters of the selection hyperslab from a pixels block parameters ensuring the total selection
   size would not exceed the limits i.e. pixels buffer size and the data range*/
bool hdf_pix_accessor::set_block_params(double &rBlock_pos, double &rBlock_size,
	size_t &n_pix_selected, size_t pix_buf_size,
	hsize_t *const block_start, hsize_t *const pix_chunk_size,
	hsize_t &n_first_block_left) {

	bool advance(true);
	bool selection_completed(false);
	// input block positions provided as in Matlab/Fortran (starting from 1) so C position is one less
	hsize_t sel_block_pos = static_cast<hsize_t>(rBlock_pos)-1;
	hsize_t sel_block_size = static_cast<hsize_t>(rBlock_size);

	/* check if we have selected enough pixels*/
	size_t n_pix_preselected(n_pix_selected);
	n_pix_preselected += sel_block_size;
	if (n_pix_preselected > pix_buf_size) {
		sel_block_size = pix_buf_size - n_pix_selected;
		/* modify partially selected block*/
		advance = false;
		selection_completed = true;
	}
	else if (n_pix_preselected == pix_buf_size) {
		advance = true;
		selection_completed = true;

	}

	/* check if we got to the end of the pixels data*/
	if (sel_block_pos + sel_block_size > this->max_num_pixels_) {
		mexErrMsgIdAndTxt("HDF_MEX_ACCESSOR:runtime_error", 
			"Attempt to read pixels beyond of existing range of the pixels");
	}


	block_start[0] = sel_block_pos;
	pix_chunk_size[0] = sel_block_size;
	n_pix_selected += sel_block_size;

	if (advance) {
		n_first_block_left++;
	}
	else {
		rBlock_size -= static_cast<double>(sel_block_size);
		rBlock_pos += static_cast<double>(sel_block_size)+1;
	}


	return selection_completed;
}

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


