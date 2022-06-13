Customizing Fur Direction
=============

Fur direction information is stored into a (Tangent Space) normal map, which should be created in external digital content creating (DCC) softwares.

If you are familiar with texture baking, the process is as follows:

- Edit surface normal direction of the mesh.

- Bake a **Object Space** normal map for this mesh.

- Apply this normal map to mesh and bake **Tangent Space** normal map.

- Assign the **(Tangent Space)** normal map to Fur Direction Map.

If you would like to create it in Unity Editor, you may try [this](https://github.com/unity3d-jp/NormalPainter). (Untested, and only avaliable in Unity 2017)

Create in Blender
-------------

To comb or brush the normal direction in Blender, an add-on is needed. 

You may try blackears's [blenderNormalBrush](https://github.com/blackears/blenderNormalBrush). (If not avaliable, please access this [fork](https://github.com/jiaozi158/blenderNormalBrush))



If you would like to support blackears, you can buy this free add-on at [blendermarket](https://blendermarket.com/products/normal-brush).



1. Open the add-on's github page and download to your computer.

2. Open Blender, import your model and enable this add-on.
   
   ![BlenderEnableAdd-ons](https://github.com/jiaozi158/ShellFurURP/blob/main/Documentation/Images/Direction/01_BlenderEnableAdd-ons.jpg)

3. Unfold the "Tool Panel" and select the add-on panel.
   
   ![NormalBrushPanel](https://github.com/jiaozi158/ShellFurURP/blob/main/Documentation/Images/Direction/02_NormalBrushPanel.jpg)

4. Adjust the settings and start to comb the normal direction.
   
   
   
   **Note: Please save your file more often.**
   
   Use "Right Click" to cancel operations and "Enter" to save and exit brush mode.
   
   ![BrushingNormals](https://github.com/jiaozi158/ShellFurURP/blob/main/Documentation/Images/Direction/03_BrushingNormals.jpg)
   
   
   
   If you would like to paint on "Selected Faces Only", you should select faces in Edit Mode:
   
   ![NormalBrushMask](https://github.com/jiaozi158/ShellFurURP/blob/main/Documentation/Images/Direction/04_NormalBrushMask.jpg)
   
   
   
   An example of brushed normal:
   
   ![BrushedNormals](https://github.com/jiaozi158/ShellFurURP/blob/main/Documentation/Images/Direction/05_BrushedNormals.jpg)
   
   

5. Go to "Edit Mode" and you will probably find sharp edges.
   
   ![MeshWithSharpEdges](https://github.com/jiaozi158/ShellFurURP/blob/main/Documentation/Images/Direction/06_SharpEdges.jpg)
   
   Select the affected parts, click "Mesh" -> "Normals" -> "Merge".
   
   ![MergeAllSharpEdges](https://github.com/jiaozi158/ShellFurURP/blob/main/Documentation/Images/Direction/07_MergeSharpEdges.jpg)
   
   No more visiable sharp edges, the mesh now has smooth normals.
   
   ![MeshWithoutSharpEdges](https://github.com/jiaozi158/ShellFurURP/blob/main/Documentation/Images/Direction/08_NoSharpEdges.jpg)

6. Select the mesh and go to "Shader Editor", then add an "Image Texture" node.
   
   ![CreateImageTextureNode](https://github.com/jiaozi158/ShellFurURP/blob/main/Documentation/Images/Direction/09_CreateImageTextureNode.jpg)

7. Click "new" to create a new image. (This one will be the Object Space normal map)
   
   ![CreateNewImage](https://github.com/jiaozi158/ShellFurURP/blob/main/Documentation/Images/Direction/10_CreateNewImage.jpg)

8. Change Blender's render engine from Eevee to Cycles. (Eevee does not support texture baking currently)
   
   
   
   Please select the texure you would like to bake to. (Notice the white highlighted outline)
   
   
   
   Scroll down and find "Bake" panel, set "Bake Type" to "Normal" and "Space" to "Object".
   
   ![BakeObjectSpaceNormalMap](https://github.com/jiaozi158/ShellFurURP/blob/main/Documentation/Images/Direction/11_BakeObjectNormalMap.jpg)

9. After baking, you can go to "Texture Paint" window and view the baked texture.
   
   ![ViewBakedObjectSpaceNormalMap](https://github.com/jiaozi158/ShellFurURP/blob/main/Documentation/Images/Direction/12_ViewBakedObjectNormalMap.jpg)
   
   
   
   It is suggested to output (and save) the Object Space fur direction map although the shader does not use it now.
   
   ![OutputBakedObjectSpaceNormalMap](https://github.com/jiaozi158/ShellFurURP/blob/main/Documentation/Images/Direction/13_OutputBakedNormalOSMap.jpg)

10. Duplicate (or copy) the brushed mesh and hide it in viewport.
    
    
    
    Select one of the mesh and go to the "Obejct Data Properties" panel.
    
    Under "Geometry Data" panel, clear its "Custom Split Normals".
    
    ![ClearBrushedNormal](https://github.com/jiaozi158/ShellFurURP/blob/main/Documentation/Images/Direction/14_ClearBrushedNormal.jpg)

11. Go back to "Shader Editor" window and add a "Normal Map" node.
    
    
    
    Connect the node with the texture and shader's normal input, then set the node to "Object Space".
    
    ![ApplyObjectSpaceNormalMapToMesh](https://github.com/jiaozi158/ShellFurURP/blob/main/Documentation/Images/Direction/15_ApplyObjectNormalMapToMesh.jpg)

12. Create a new image. (This one will be the Tangent Space normal map)
    
    
    
    Please select the texure you would like to bake to.
    
    
    
    Go to "Bake" panel, set "Space" to "Tangent" and bake the texture.
    
    ![BakeTangentSpaceNormalMap](https://github.com/jiaozi158/ShellFurURP/blob/main/Documentation/Images/Direction/16_BakeTangentNormalMap.jpg)

13. After baking, go to "Texture Paint" window and view the baked texture.
    
    ![ViewBakedTangentSpaceNormalMap](https://github.com/jiaozi158/ShellFurURP/blob/main/Documentation/Images/Direction/17_ViewBakedTangentNormalMap.jpg)

14. Output this Tangent Space normal map.
    
    
    
    It is suggested to use 0% compression or 100% (Loseless)
    
    ![OutputBakedFurDirectionMap](https://github.com/jiaozi158/ShellFurURP/blob/main/Documentation/Images/Direction/18_OutputBakedNormalTSMap.jpg)
