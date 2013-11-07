/*==============================================================================
 Copyright (c) 2012-2013 QUALCOMM Austria Research Center GmbH.
 All Rights Reserved.
 Qualcomm Confidential and Proprietary
 ==============================================================================*/

#import <UIKit/UIKit.h>

typedef enum {
    kTargetStatusRequesting,
    kTargetStatusNone
} TargetStatus;

@interface QCARHelper : NSObject
{
    
}

+(TargetStatus)targetStatus;
+(NSString*) errorStringFromCode:(int) code;

+ (void) startDetection;
+ (void) stopDetection;

+ (BOOL) isRetinaDevice;
@end
