// Rebuild with meshoptimizer 1.2.0. Set GLTF_MESHOPT_ENCODER_MODULE to its encoder module URL if not installed locally.
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
const {MeshoptEncoder:E}=await import(process.env.GLTF_MESHOPT_ENCODER_MODULE || 'meshoptimizer'); await E.ready;
const out=process.argv[2] || fileURLToPath(new URL('../GLTFSwiftTests/Resources',import.meta.url));
const chunks=[],views=[],accessors=[],map={};let encodedOffset=0,decodedOffset=0;
function add(name,source,count,stride,type,componentType,normalized=false,mode='ATTRIBUTES',filter='NONE',offset=0,accessorCount=count){
 const bytes=new Uint8Array(source.buffer,source.byteOffset,source.byteLength);const encoded=E.encodeGltfBuffer(bytes,count,stride,mode);
 const view={buffer:1,byteOffset:decodedOffset,byteLength:count*stride,extensions:{EXT_meshopt_compression:{buffer:0,byteOffset:encodedOffset,byteLength:encoded.length,byteStride:stride,count,mode,filter}}};
 if(mode==='ATTRIBUTES')view.byteStride=stride;
 views.push(view);chunks.push(encoded);encodedOffset+=encoded.length;decodedOffset+=count*stride;
 const a={name,bufferView:views.length-1,componentType,count:accessorCount,type};if(normalized)a.normalized=true;if(offset)a.byteOffset=offset;
 accessors.push(a);map[name]=accessors.length-1;return accessors.length-1;
}
add('positions',new Int16Array([-32768,0,0,123,32767,0,0,123,0,32767,0,123]),3,8,'VEC3',5122,true);
const normals=E.encodeFilterOct(new Float32Array([0,0,1,0,0,0,1,0,0,0,1,0]),3,4,8);
add('normals',normals,3,4,'VEC3',5120,true,'ATTRIBUTES','OCTAHEDRAL');
add('uv',new Uint16Array([0,0,65535,0,32768,65535]),3,4,'VEC2',5123,true);
add('triangles',new Uint16Array([0,1,2]),3,2,'SCALAR',5123,false,'TRIANGLES');
add('deltaA',new Int16Array([0,16384,0,0,0,16384,0,0,0,16384,0,0]),3,8,'VEC3',5122,true);
add('deltaB',new Int16Array([32767,0,0,0,32767,0,0,0,32767,0,0,0]),3,8,'VEC3',5122,true);
add('times',E.encodeFilterExp(new Float32Array([0,10]),2,4,24),2,4,'SCALAR',5126,false,'ATTRIBUTES','EXPONENTIAL');
add('weights',new Float32Array([1,0,0,1]),4,4,'SCALAR',5126);
add('sequence',new Uint32Array([99,2,1,0,2,1]),6,4,'SCALAR',5125,false,'INDICES','NONE',4,5);
add('quaternions',E.encodeFilterQuat(new Float32Array([0,0,0,1,0,Math.SQRT1_2,0,Math.SQRT1_2]),2,8,16),2,8,'VEC4',5122,true,'ATTRIBUTES','QUATERNION');
add('exponential',E.encodeFilterExp(new Float32Array([1.25,-2.5,100,0.125,64,-0.5]),2,12,20),2,12,'VEC3',5126,false,'ATTRIBUTES','EXPONENTIAL');
const g={asset:{version:'2.0',generator:'GLTFSwift feature fixture; meshoptimizer 1.2.0'},extensionsRequired:['EXT_meshopt_compression','KHR_mesh_quantization'],extensionsUsed:['EXT_meshopt_compression','KHR_mesh_quantization'],scenes:[{nodes:[0]}],nodes:[{mesh:0,weights:[1,0],translation:[5,0,0],scale:[2,2,2]}],meshes:[{weights:[.25,.75],primitives:[{indices:map.triangles,attributes:{POSITION:map.positions,NORMAL:map.normals,TEXCOORD_0:map.uv},targets:[{POSITION:map.deltaA},{POSITION:map.deltaB}]}]}],animations:[{name:'Water',samplers:[{input:map.times,output:map.weights}],channels:[{sampler:0,target:{node:0,path:'weights'}}]}],buffers:[{byteLength:encodedOffset,uri:'meshopt-features.bin'},{byteLength:decodedOffset,extensions:{EXT_meshopt_compression:{fallback:true}}}],bufferViews:views,accessors,extras:{accessorMap:map}};
fs.mkdirSync(out,{recursive:true});fs.writeFileSync(path.join(out,'meshopt-features.gltf'),JSON.stringify(g,null,2));fs.writeFileSync(path.join(out,'meshopt-features.bin'),Buffer.concat(chunks));
