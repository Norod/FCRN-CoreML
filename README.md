# FCRN-CoreML sample app
## iOS and macOS

Depth Estimation sample Apps for iOS and macOS, using the FCRN-DepthPrediction models Apple provided on their [model page](https://developer.apple.com/machine-learning/models/). 

<img src="images/fcrn16-iOS.jpg" alt="fcrn16-iOS" width="50%" height="50%"> <img src="images/fcrn16-macOS.jpg" alt="fcrn16-macOS" width="100%" height="100%"> 

* Loads an image and crops it to the size requested by the model
* The same helper class provides hardware accelerated for both iOS and macOS
* Supports both _FCRN-16_ and _FCRN-32_ models 
* You can run _convertOutput.sh_ to batch convert them into jpg's
* Before you try the sample App you need to download a model and save it in the _mlmodel_ folder

You can download FCRN-DepthPrediction CoreML models from [https://developer.apple.com/machine-learning/models/](https://developer.apple.com/machine-learning/models/)

You can download just one of them, both work with this project.
Choose which one to use by setting the relevant build target in Xcode

FCRN.mlmodel
Storing model weights using full precision (32 bit) floating points numbers.
254.7MB
[https://docs-assets.developer.apple.com/coreml/models/Image/DepthEstimation/FCRN/FCRN.mlmodel](https://docs-assets.developer.apple.com/coreml/models/Image/DepthEstimation/FCRN/FCRN.mlmodel)

FCRNFP16.mlmodel
Storing model weights using half-precision (16 bit) floating points numbers.
127.3MB
[https://docs-assets.developer.apple.com/coreml/models/Image/DepthEstimation/FCRN/FCRNFP16.mlmodel](https://docs-assets.developer.apple.com/coreml/models/Image/DepthEstimation/FCRN/FCRNFP16.mlmodel)