//
//  SilenceDeprecation.h
//  Endless
//
//  Created by Benjamin Erhart on 12.03.19.
//  Copyright © 2019 jcs. All rights reserved.
//

#ifndef SilenceDeprecation_h
#define SilenceDeprecation_h

#define SILENCE_DEPRECATION_ON											\
_Pragma("clang diagnostic push")										\
_Pragma("clang diagnostic ignored \"-Wdeprecated-declarations\"")		\
_Pragma("clang diagnostic ignored \"-Wdeprecated-implementations\"")

#define SILENCE_DEPRECATION_OFF											\
_Pragma("clang diagnostic pop")

#define SILENCE_DEPRECATION(expr)										\
do {																	\
_Pragma("clang diagnostic push")										\
_Pragma("clang diagnostic ignored \"-Wdeprecated-declarations\"")		\
_Pragma("clang diagnostic ignored \"-Wdeprecated-implementations\"")	\
expr;																	\
_Pragma("clang diagnostic pop")											\
} while(0)

#endif /* SilenceDeprecation_h */
