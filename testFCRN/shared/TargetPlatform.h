//
//  TargetPlatform.h
//  testFCRN
//
//  Created by Doron Adler on 28/07/2019.
//  Copyright © 2019 Doron Adler. All rights reserved.
//

#ifndef TargetPlatform_h
#define TargetPlatform_h

// -----------------------------------------------------------------------------


// -----------------------------------------------------------------------------
// Provide the correct #ifdef environemnt for the headers when included from an external client
//
#if ((defined(TARGET_OS_WATCH) && (TARGET_OS_WATCH == 1)))
    #if !defined(WATCHOS_TARGET)
        #define WATCHOS_TARGET
    #endif //WATCHOS_TARGET
#endif

#if ((defined(TARGET_OS_OSX) && (TARGET_OS_OSX == 1)))
    #if !defined(MACOS_TARGET)
        #define MACOS_TARGET
    #endif //MACOS_TARGET
#endif

#if ((defined(TARGET_OS_IOS) && (TARGET_OS_IOS == 1)))
    #if !defined(IOS_TARGET)
        #define IOS_TARGET
    #endif //IOS_TARGET
#endif

#endif /* TargetPlatform_h */
