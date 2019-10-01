#pragma once

#include <cuda_runtime.h>
#include <nv/helper_math.h>
#include "attribute.hpp"

namespace vol
{
struct Box3D
{
	VOL_DEFINE_ATTRIBUTE( float3, min );
	VOL_DEFINE_ATTRIBUTE( float3, max );

public:
	__host__ __device__ float3 center() const { return ( min + max ) / 2; }
};

inline std::ostream &operator<<( std::ostream &os, Box3D const &box )
{
	os << "Box3D(("
	   << box.min.x << "," << box.min.y << "," << box.min.z << "),("
	   << box.max.x << "," << box.max.y << "," << box.max.z << "))";
	return os;
}

struct Ray3D
{
	VOL_DEFINE_ATTRIBUTE( float3, o );
	VOL_DEFINE_ATTRIBUTE( float3, d );

public:
	__host__ __device__ bool intersect( Box3D const &box, float &tnear, float &tfar )
	{
		float3 invr = float3{ 1., 1., 1. } / d;
		float3 tbot = invr * ( box.min - o );
		float3 ttop = invr * ( box.max - o );

		float3 tmin = fminf( ttop, tbot );
		float3 tmax = fmaxf( ttop, tbot );

		tnear = fmaxf( fmaxf( tmin.x, tmin.y ), tmin.z );
		tfar = fminf( fminf( tmax.x, tmax.y ), tmax.z );

		return tfar > tnear;
	}
};
}