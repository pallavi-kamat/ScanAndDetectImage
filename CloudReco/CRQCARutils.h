/*==============================================================================
 Copyright (c) 2012-2013 QUALCOMM Austria Research Center GmbH.
 All Rights Reserved.
 Qualcomm Confidential and Proprietary
 ==============================================================================*/

#import <Foundation/Foundation.h>
#import "QCARutils.h"
#import "Book.h"

typedef enum {
    DeviceOrientationLockPortrait,
    DeviceOrientationLockLandscape,
    DeviceOrientationLockAuto
} DeviceOrientationLock;

@interface CRQCARutils : QCARutils <UIAlertViewDelegate>{
    BOOL isShowingAnAlertView;
    NSString *lastTargetIDScanned;
    Book *lastScannedBook;
    DeviceOrientationLock deviceOrientationLock;
}

@property (copy) NSString *lastTargetIDScanned;
@property (retain) Book *lastScannedBook;
@property (assign) DeviceOrientationLock deviceOrientationLock;

+ (CRQCARutils *) getInstance;
- (void) showUIAlertFromErrorCode:(int) code;
- (BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation;
@end
