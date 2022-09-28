ShellFurURP
=============

 Shell-based Fur shader for Unity's URP (Universal Render Pipeline).

 Now support GPUs without geometry shader support. (using Multi-Pass Fur)
 
 Based on hecomi's [UnityFurURP](https://github.com/hecomi/UnityFurURP).
 
 Containing four demo scenes:
 - High Fidelity
 - Performant
 - BakedLighting
 - Multi-Pass Fur
 
 Please change the Project Quality from "HighFidelity" to "Performant" if opening "Performant" scene.
 
Screenshots
------------
**(High Fidelity Scene)**

 ![HighFidelity1](https://github.com/jiaozi158/ShellFurURP/blob/main/Documentation/Images/Demo/HighFidelity/HighFidelity1_new.jpg)
 
 ![HighFidelity2](https://github.com/jiaozi158/ShellFurURP/blob/main/Documentation/Images/Demo/HighFidelity/HighFidelity2_new.jpg)

**(Performant Scene)**
 
 ![Performant1](https://github.com/jiaozi158/ShellFurURP/blob/main/Documentation/Images/Demo/Performant/Performant1_new.jpg)
 
 ![Performant2](https://github.com/jiaozi158/ShellFurURP/blob/main/Documentation/Images/Demo/Performant/Performant2_new.jpg)
 
**(BakedLighting Scene)**
 
 Using Enlighten Realtime GI because I did not create a proper lightmapUV (which Progressive Lightmapper requires) for "PlushyToy" mesh.
 
 ![BakedLighting1](https://github.com/jiaozi158/ShellFurURP/blob/main/Documentation/Images/Demo/BakedLighting/BakedLighting1_new.jpg)

**(Multi-Pass Fur Scene)**

 The same as High Fidelity/Performant scene.

 Click [here](https://github.com/jiaozi158/ShellFurURP/blob/main/Documentation/Multi-PassFur.md) to know more about Multi-Pass Fur.

all with SSAA X16 enabled. ~~(current URP does not have effective AA method.)~~

 **Note:** Anti-aliasing has improved a lot on URP 14/15. (MSAA Alpha-To-Coverage, TAA)

Documentation
------------
You can find it [here](https://github.com/jiaozi158/ShellFurURP/blob/main/Documentation/Documentation.md).

Requirements
------------
- URP 12.1 and above.
- Geometry Shader Supported GPU. (For Geometry Shader Fur)
- Common GPUs. (For Multi-Pass Fur)

License
------------
MIT ![MIT License](http://img.shields.io/badge/license-MIT-blue.svg?style=flat)

This repository contains code and assets from other repositories.

A complete list of licenses can be found [here](https://github.com/jiaozi158/ShellFurURP/blob/main/LICENSE).
