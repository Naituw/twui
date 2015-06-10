//
//  TUIPinchGestureRecognizer.h
//  TwUI
//
//  Created by 吴天 on 12/14/14.
//
//

#import "TUIGestureRecognizer.h"

// Begins:  when two touches have moved enough to be considered a pinch
// Changes: when a finger moves while two fingers remain down
// Ends:    when both fingers have lifted

@interface TUIPinchGestureRecognizer : TUIGestureRecognizer

@property (nonatomic) CGFloat scale;

@end
