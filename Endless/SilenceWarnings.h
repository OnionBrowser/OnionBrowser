//
//  SilenceWarnings.h
//  Endless
//
//  Created by Benjamin Erhart on 12.03.19.
//  Copyright © 2019 jcs. All rights reserved.
//

#ifndef SilenceWarnings_h
#define SilenceWarnings_h

#define SILENCE_DEPRECATION_ON											\
_Pragma("clang diagnostic push")										\
_Pragma("clang diagnostic ignored \"-Wdeprecated-declarations\"")		\
_Pragma("clang diagnostic ignored \"-Wdeprecated-implementations\"")

#define SILENCE_DEPRECATION(expr)										\
do {																	\
_Pragma("clang diagnostic push")										\
_Pragma("clang diagnostic ignored \"-Wdeprecated-declarations\"")		\
_Pragma("clang diagnostic ignored \"-Wdeprecated-implementations\"")	\
expr;																	\
_Pragma("clang diagnostic pop")											\
} while(0)

#define SILENCE_PERFORM_SELECTOR_LEAKS_ON								\
_Pragma("clang diagnostic push")										\
_Pragma("clang diagnostic ignored \"-Warc-performSelector-leaks\"")

#define SILENCE_PERFORM_SELECTOR_LEAKS(expr)							\
do {																	\
_Pragma("clang diagnostic push")										\
_Pragma("clang diagnostic ignored \"-Warc-performSelector-leaks\"")		\
expr;																	\
_Pragma("clang diagnostic pop")											\
} while(0)

#define SILENCE_WARNINGS_OFF											\
_Pragma("clang diagnostic pop")

#endif /* SilenceWarnings_h */
