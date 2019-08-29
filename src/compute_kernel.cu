#include "compute_kernel.hpp"
#include <cuda/array.hpp>
#include <utils/math.hpp>

namespace vol
{
texture<Voxel, 3, cudaReadModeNormalizedFloat> tex;
texture<float4, 1, cudaReadModeElementType> transfer_tex;

__global__ void render_kernel_impl( cuda::ImageView<Pixel> out )
{
	const int max_steps = 500;
	const float tstep = 0.01f;
	const float opacity_threshold = 0.95f;
	const float density = .05f;
	const float brightness = 1.f;

	uint x = blockIdx.x * blockDim.x + threadIdx.x;
	uint y = blockIdx.y * blockDim.y + threadIdx.y;

	if ( x >= out.width() || y >= out.height() ) {
		return;
	}

	float u = x / float( out.width() ) * 2.f - 1.f;
	float v = y / float( out.height() ) * 2.f - 1.f;

	auto box = Box3D{};
	box.min = float3{ -1, -1, -1 };
	box.max = float3{ 1, 1, 1 };

	auto eye = Ray3D{};
	eye.o = float3{ 0, 0, 4 };
	eye.d = float3{ u, v, -2 };

	float tnear, tfar;
	if ( !eye.intersect( box, tnear, tfar ) ) {
		return;
	}

	float4 sum = { 0 };
	auto t = tnear;
	auto pos = eye.o + eye.d * t;
	auto step = eye.d * tstep;

	int i;
	for ( i = 0; i < max_steps; ++i ) {
		float sample = tex3D( tex,
							  pos.x * .5 + .5,
							  pos.y * .5 + .5,
							  pos.z * .5 + .5 );
		float4 col = tex1D( transfer_tex, sample ) * density;
		sum += col * ( 1.f - sum.w );
		if ( sum.w > opacity_threshold ) break;
		t += tstep;
		if ( t > tfar ) break;
		pos += step;
	}

	sum *= brightness;

	out.at_device( x, y )._ = sum;
	// out.at_device( x, y )._ = { float( i ) / 2 / max_steps + .5, 0, 0, 1 };
	// auto p = eye.o + eye.d * tnear * .5 + .5;
	// out.at_device( x, y )._ = { p.x, p.y, p.z, 1 };
}

VOL_DEFINE_CUDA_KERNEL( render_kernel, render_kernel_impl );

namespace _
{
static int __ = [] {
	tex.normalized = true;
	tex.filterMode = cudaFilterModeLinear;
	tex.addressMode[ 0 ] = cudaAddressModeClamp;
	tex.addressMode[ 1 ] = cudaAddressModeClamp;

	transfer_tex.filterMode = cudaFilterModeLinear;
	transfer_tex.normalized = true;
	transfer_tex.addressMode[ 0 ] = cudaAddressModeClamp;

	static float4 transfer_fn[] = {
		{ 0., 0., 0., 0. },
		{ 1., 0., 0., 1. },
		{ 1., .5, 0., 1. },
		{ 1., 1., 0., 1. },
		{ 0., 1., 0., 1. },
		{ 0., 1., 1., 1. },
		{ 0., 0., 1., 1. },
		{ 1., 0., 1., 1. },
		{ 0., 0., 0., 0. },
	};
	static cuda::Array1D<float4>
	  transfer_arr( sizeof( transfer_fn ) / sizeof( transfer_fn[ 0 ] ) );
	auto transfer_fn_view = cuda::MemoryView1D<float4>( transfer_fn, transfer_arr.size() );
	auto res = cuda::memory_transfer( transfer_arr, transfer_fn_view ).launch();
	std::cout << res << std::endl;
	transfer_arr.bind_to_texture( transfer_tex );

	return 0;
}();
}

void bind_texture( cuda::Array3D<Voxel> const &arr )
{
	arr.bind_to_texture( tex );
}

}  // namespace vol
