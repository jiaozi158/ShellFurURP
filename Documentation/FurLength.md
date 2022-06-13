Customizing Fur Length
=============

Fur length information is stored into a (2D) texture, which should be created in external digital content creating (DCC) softwares.

The fur length texture provides a 0-1 color value to adjust the actual "Total Shell Step" parameter.

![Example](https://github.com/jiaozi158/ShellFurURP/blob/main/Documentation/Images/Length/Length_00_Example.jpg)

You can create this texture in any DCC that you are familiar with.

Create in Blender
-------------

1. Import your model into Blender.

2. Select the mesh and change "Timeline" to "Shader Editor".

   Add an image texture node.

   ![CreateImageTextureNode](https://github.com/jiaozi158/ShellFurURP/blob/main/Documentation/Images/Length/Length_01_CreateImageTextureNode.jpg)

3. Click "new" to create a new image.

   ![ClickNew](https://github.com/jiaozi158/ShellFurURP/blob/main/Documentation/Images/Length/Length_02_CreateNewImage.jpg)

4. Remember to use White as default color.

   ![CreateWhiteImageTexture](https://github.com/jiaozi158/ShellFurURP/blob/main/Documentation/Images/Length/Length_03_NewImageParams.jpg)

5. Open "Particle Properties" panel and click "+" to add a new particle system for the mesh.

   Change the following settings to any suitable values:

   ![CreateHairParticles](https://github.com/jiaozi158/ShellFurURP/blob/main/Documentation/Images/Length/Length_04_CreateHairParticles1.jpg)

   **Note: We will use this particle system to better visualize the Fur Length Map.**

6. Scroll down and set child particle to "Interpolated", you may increase "Display Amount" if needed.

   ![CreateHairChildParticles](https://github.com/jiaozi158/ShellFurURP/blob/main/Documentation/Images/Length/Length_05_CreateHairParticles2.jpg)

7. Open "Texture Properties" panel and add a new texture.

   ![TexturePropertiesPanel](https://github.com/jiaozi158/ShellFurURP/blob/main/Documentation/Images/Length/Length_06_TextureProperties.jpg)

8. Set the texture type to "Image or Movie" and select the image created in step 4.

   ![SetLengthImage](https://github.com/jiaozi158/ShellFurURP/blob/main/Documentation/Images/Length/Length_07_SetLengthImage.jpg)

9. Go back to "Particle Properties" panel and set the texture assigned in step 8.

   ![SetTextureForHair](https://github.com/jiaozi158/ShellFurURP/blob/main/Documentation/Images/Length/Length_08_SetTextureForHair.jpg)

10. Reopen "Texture Properties" panel.

    Find "Influence" and tick "Hair Length" with value 1.

    Find "Mapping" (under the "Influence") and set coordinates to "UV".

    Choose the **correct** UV for "Map".

    **Note: In most cases, this should be the first UV.**

    ![EnableHairLengthAndSetUV](https://github.com/jiaozi158/ShellFurURP/blob/main/Documentation/Images/Length/Length_09_TextureAffectHairLengthAndUV.jpg)

11. Enter "Texture Paint" mode and you will be able to paint length map now.

    **Note:** Please save the **file** and **texture** from time to time.

    ![PaintingLengthAndExportImage](https://github.com/jiaozi158/ShellFurURP/blob/main/Documentation/Images/Length/Length_10_PaintingLengthAndOutput.jpg)