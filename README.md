# UnityShaderStudy

本仓库是在学习冯乐乐的《Unity Shader入门精要》时，跟着书上的例子写的一些shader。

## 包含内容

### 书本中的例子

`Asserts/Shaders`下的shader是书中的例子。

### 仿原神角色渲染的shader

`Assets\Models\GenshinCharacterXXXShader`是仿原神角色渲染的shader，分为头发、身体与脸部三个shader。

分别实现了以下效果：
- diffuse
- specular
- edge highlight (效果不是很好)
- normal map

shader的初始参数并不是很好，需要自己手动去调整。

预览：

![整体效果](./imgs/%E6%95%B4%E4%BD%93%E6%95%88%E6%9E%9C.png)