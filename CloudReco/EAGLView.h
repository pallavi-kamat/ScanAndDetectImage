/*==============================================================================
 Copyright (c) 2012-2013 QUALCOMM Austria Research Center GmbH.
 All Rights Reserved.
 Qualcomm Confidential and Proprietary
 ==============================================================================*/

#import "AR_EAGLView.h"
#import "Transition3Dto2D.h"
#import "BooksManagerDelegateProtocol.h"
#import "ImagesManagerDelegateProtocol.h"


// This class wraps the CAEAGLLayer from CoreAnimation into a convenient UIView
// subclass.  The view content is basically an EAGL surface you render your
// OpenGL scene into.  Note that setting the view non-opaque will only work if
// the EAGL surface has an alpha channel.
@interface EAGLView : AR_EAGLView <BooksManagerDelegateProtocol, ImagesManagerDelegateProtocol>
{
    GLuint tID;
    BOOL trackingTextureAvailable;
    BOOL isViewingTarget;
    BOOL isShowing2DOverlay;
    
    // Lock to prevent concurrent access of the framebuffer on the main and
    // render threads (layoutSubViews and renderFrameQCAR methods)
    NSLock *framebufferLock;
    
    // ----------------------------------------------------------------------------
    // 3D to 2D Transition control variables
    // ----------------------------------------------------------------------------
    Transition3Dto2D* transition3Dto2D;
    Transition3Dto2D* transition2Dto3D;
    
    bool startTransition;
    bool startTransition2Dto3D;
    
    bool reportedFinished;
    bool reportedFinished2Dto3D;
    
    int renderState;
    float transitionDuration;

    // ----------------------------------------------------------------------------
    // Trackable Data Global Variables
    // ----------------------------------------------------------------------------
    const QCAR::TrackableResult* trackableResult;
    QCAR::Vec2F trackableSize;
    QCAR::Matrix34F pose;
    QCAR::Matrix44F projectionMatrix;

    // ----------------------------------------------------------------------------
    // Texture used to Draw the 3d and 2D Overlay with Book Data
    // ----------------------------------------------------------------------------
    Texture *thisTexture;
}

- (void)setOverlayLayer:(CALayer *)overlayLayer;
- (void)enterScanningMode;

- (BOOL)isPointInsideAROverlay:(CGPoint)aPoint;

@property (assign) int renderState;

@end
