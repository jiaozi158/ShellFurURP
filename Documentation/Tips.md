TIPS
=============

IMPORTANT
------------

Before customizing the fur, you should ensure that the model has even UV.

evenly mapped UV:

 ![EvenlyMappedUV](https://github.com/jiaozi158/ShellFurURP/blob/main/Documentation/Images/Tips/EvenlyMappedUV.png)

unevenly mapped UV:

 ![UnevenlyMappedUV](https://github.com/jiaozi158/ShellFurURP/blob/main/Documentation/Images/Tips/UnevenlyMappedUV.png)


It is suggested to adjust URP shadow bias. (URP Asset or Per Light)

example of a proper shadow bias:

 ![URPAssetShadowBias](https://github.com/jiaozi158/ShellFurURP/blob/main/Documentation/Images/Tips/Fur_ShadowBias.jpg)


Performance Tips
------------

To keep an acceptable frame rate on wider range of devices, it is suggested to:

- Use the fewest shell layers while maintaining an acceptable appearance.

- Reduce Mesh (covered with fur) vertices while maintaining an acceptable appearance.

- Future work: It is possible to use two meshes separately. The one with fewer vertices can be used for fur generating.


Higher Fidelity Tips
------------

You may increase the maximum shell layers to improve fur quality. (52 shells -> more)

Please click [here (unfinished)]() for detailed instructions.

