//
//  Cardex.m
//  ControllerLib
//
//  Created by lingguang1997 on 11/3/12.
//  Copyright (c) 2012 lingguang1997. All rights reserved.
//

#import "Cardex.h"

static const NSUInteger DEFAULT_NUMBER_OF_VISIBLE_ITEMS = 20;
static const CGFloat DEFAULT_PERSPECTIVE = - 1.0f / 500.0f;
static const CGFloat DEFAULT_GRADIENT = - M_PI / 6;
static const CGFloat DEFAULT_3D_TRANSFORM_Z_FACTOR = .8f;
static const CGFloat DEFAULT_DECELERATION_RATE = .95f;
static const CGFloat DEFAULT_FRAME_RATE = 1.0f / 60.0f;
static const CGFloat SPEED_UP_FACTOR = 1.0f;
static const NSUInteger DEFAULT_FIRST_ITEM_VIEW_INDEX = 0;
static const CGFloat DECELERATION_FACTOR = 30.0f;



void *cardexIndexKey;

@interface CardexView () {
    enum CardexStatus {
        STOP,
        READY_TO_SCROLL,
        SCROLLING_BY_DRAGGING,
        DECELERATING,
    };
}

@property (assign, nonatomic) NSUInteger numberOfItems;
@property (assign, nonatomic) CGFloat previousTranslation;

@property (strong, nonatomic) NSMutableDictionary *idxToItemView;
@property (strong, nonatomic) NSMutableSet *itemViewPool;
@property (assign, nonatomic) CGFloat itemViewHeight;
@property (assign, nonatomic) CGFloat itemViewWidth;
@property (assign, nonatomic) CGPoint firstItemViewOrigin;
@property (assign) NSInteger status;
@property (assign, nonatomic) CGFloat scrollOffset;
@property (assign, nonatomic) CGFloat startVelocity;
@property (assign, nonatomic) NSTimeInterval lastStepTime;
@property (assign, nonatomic) NSTimer *timer;
@property (assign) NSTimeInterval startTime;
@property (assign, nonatomic) CGFloat frameRate;
@property (assign, nonatomic) CGFloat decelerationDuration;

- (void)reset;
- (void)setUp;
- (UIView *)loadItemViewWithItemIndex:(NSUInteger)itemIndex
                          CardexIndex:(NSInteger)cardexIndex;
- (void)queueItemView:(UIView *)view;
- (UIView *)dequeueItemView;
- (void)layoutSubviews;
- (void)validateMaxNumberOfVisibleItems:(NSUInteger)maxNumberOfVisibleItems;
- (void)validateFirstItemViewIndex:(NSUInteger)firstItemViewIndex;

- (NSArray *)getSortedIndexes;
- (void)didPan:(UIPanGestureRecognizer *)panGestureRecognizer;
- (void)dragging;
- (void)step;
- (BOOL)shouldDecrementFirstItemIndex;
- (BOOL)isOutOfBoundsOfCardexView:(UIView *)view;
- (void)transformItemView:(UIView *)view withOffset:(CGFloat)offset;
- (void)transformItemView:(UIView *)view
                  atIndex:(NSInteger)index
     dependsOnViewOfIndex:(NSInteger)anIndex;
- (CGFloat)decelerationDistance;
- (void)startDecelerating;
- (void)scrollByOffset:(CGFloat)offset;
- (void)loadUnloadViewsByScrollDirection:(BOOL)removeFront;
- (BOOL)tryAndLoadItemViewWithItemIndex:(NSUInteger)itemIndex
                            CardexIndex:(NSInteger)cardexIndex
                   dependsOnViewOfIndex:(NSInteger)anotherItemIndex;

@end

@implementation CardexView
@synthesize dataSource = _dataSource;
@synthesize delegate = _delegate;
@synthesize numberOfItems = _numberOfItems;
@synthesize maxNumberOfVisibleItems = _maxNumberOfVisibleItems;
@synthesize previousTranslation = _previousTranslation;
@synthesize contentView = _contentView;
@synthesize firstItemViewIndex = _firstItemViewIndex;
@synthesize zOffsetRate = _zOffsetRate;
@synthesize perspective = _perspective;
@synthesize gradient = _gradient;
@synthesize itemViewHeight = _itemViewHeight;
@synthesize itemViewWidth = _itemViewWidth;
@synthesize firstItemViewOrigin = _firstItemViewOrigin;
@synthesize status = _status;
@synthesize scrollOffset = _scrollOffset;
@synthesize startVelocity = _startVelocity;
@synthesize startTime = _startTime;
@synthesize frameRate = _frameRate;
@synthesize decelerationRate = _decelerationRate;
@synthesize decelerationDuration = _decelerationDuration;
@synthesize lastStepTime = _lastStepTime;

@synthesize idxToItemView = _idxToItemView;
@synthesize itemViewPool = _itemViewPool;
@synthesize timer = _timer;

#pragma mark - @Override

- (id)init {
    self = [super init];
    if (self) {
        [self setUp];
    }
    return self;
}

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setUp];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self setUp];
    }
    return self;
}

- (void)dealloc {
    [_contentView release];
    [_idxToItemView release];
    [_itemViewPool release];
    [super dealloc];
}

- (void)setDataSource:(id<CardexDataSource>)dataSource {
    if (_dataSource != dataSource) {
        _dataSource = dataSource;
        if (_dataSource) {
            [self reloadData];
        }
    }
}

- (void)setMaxNumberOfVisibleItems:(NSUInteger)maxNumberOfVisibleItems {
    [self validateMaxNumberOfVisibleItems:maxNumberOfVisibleItems];
    NSUInteger num = MIN(_numberOfItems, maxNumberOfVisibleItems);
    if (_maxNumberOfVisibleItems != num) {
        _maxNumberOfVisibleItems = maxNumberOfVisibleItems;
        if (_dataSource) {
            [self reloadData];
        }
    }
}

- (void)setFirstItemViewIndex:(NSUInteger)firstItemViewIndex {
    [self validateFirstItemViewIndex:firstItemViewIndex];
    if (_firstItemViewIndex != firstItemViewIndex) {
        _firstItemViewIndex = firstItemViewIndex;
        if (_dataSource) {
            [self reloadData];
        }
    }
}

- (void)setZOffsetRate:(CGFloat)zOffsetRate {
    if (_zOffsetRate != zOffsetRate) {
        _zOffsetRate = zOffsetRate;
        if (_dataSource) {
            [self reloadData];
        }
    }
}

- (void)setPerspective:(CGFloat)perspective {
    if (_perspective != perspective) {
        _perspective = perspective;
        if (_dataSource) {
            [self reloadData];
        }
    }
}

- (void)setGradient:(CGFloat)gradient {
    if (_gradient != gradient) {
        if (_dataSource) {
            [self reloadData];
        }
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];
    _contentView.frame = CGRectMake(0, 0,
                                    self.bounds.size.width,
                                    self.bounds.size.height);
    NSArray *sortedIndexes = [self getSortedIndexes];
    for (NSNumber *n in sortedIndexes) {
        UIView *v = [_idxToItemView objectForKey:n];
        int cardexIndex = [objc_getAssociatedObject(v, &cardexIndexKey)
                           integerValue];
        [self transformItemView:v atIndex:cardexIndex];
        if ([n integerValue] == 0) {
            _firstItemViewOrigin = v.frame.origin;
        }
    }
}
/*
 // Only override drawRect: if you perform custom drawing.
 // An empty implementation adversely affects performance during animation.
 - (void)drawRect:(CGRect)rect
 {
 // Drawing code
 }
 */

#pragma mark - private methods

- (void)reset {
    _numberOfItems = 0;
    _maxNumberOfVisibleItems = DEFAULT_NUMBER_OF_VISIBLE_ITEMS;
    _firstItemViewIndex = DEFAULT_FIRST_ITEM_VIEW_INDEX;
    _zOffsetRate = DEFAULT_3D_TRANSFORM_Z_FACTOR;
    _perspective = DEFAULT_PERSPECTIVE;
    _gradient = DEFAULT_GRADIENT;
    _itemViewHeight = 0;
    _itemViewWidth = 0;
    _firstItemViewOrigin = CGPointZero;
    _status = STOP;
    _scrollOffset = .0f;
    _startVelocity = .0f;
    _startTime = 0;
    _frameRate = DEFAULT_FRAME_RATE;
    _decelerationRate = DEFAULT_DECELERATION_RATE;
}

- (void)setUp {
    [self reset];
    self.autoresizingMask = UIViewAutoresizingFlexibleTopMargin
    | UIViewAutoresizingFlexibleBottomMargin
    | UIViewAutoresizingFlexibleWidth
    | UIViewAutoresizingFlexibleHeight
    | UIViewAutoresizingFlexibleLeftMargin
    | UIViewAutoresizingFlexibleRightMargin;
    
    if (_contentView) {
        [_contentView release];
    }
    _contentView = [[UIView alloc] initWithFrame:self.bounds];
    _contentView.backgroundColor = [UIColor redColor];

    self.backgroundColor = [UIColor blackColor];
    
    UIPanGestureRecognizer *panGR =
    [[UIPanGestureRecognizer alloc] initWithTarget:self
                                            action:@selector(didPan:)];
    panGR.delegate = self;
    [_contentView addGestureRecognizer:panGR];
    [panGR release];
    [self addSubview:_contentView];
}

- (void)reloadData {
    // clear visible items from content view
    for (UIView *v in [_idxToItemView allValues]) {
        [v removeFromSuperview];
    }

    // clear collection of visible items and pool
    self.idxToItemView =
    [NSMutableDictionary dictionaryWithCapacity:_maxNumberOfVisibleItems];
    self.itemViewPool = [NSMutableSet setWithCapacity:_maxNumberOfVisibleItems];

    if (_dataSource == nil) {
        NSLog(@"Cardex: the data source is nil!");
        return;
    }
    _numberOfItems = [_dataSource numberOfItemsInCardexView:self];
    NSAssert(_numberOfItems > 0, @"The number of items must be positive!");
    if ([_dataSource respondsToSelector:
         @selector(numberOfVisibleItemsInCardexView:)]) {
        _maxNumberOfVisibleItems =
        [_dataSource maxNumberOfVisibleItemsInCardexView:self];
        [self validateMaxNumberOfVisibleItems:_maxNumberOfVisibleItems];
    }
    if ([_dataSource respondsToSelector:
         @selector(firstItemIndexInCardexView:)]) {
        _firstItemViewIndex = [_dataSource firstItemIndexInCardexView:self];
        [self validateFirstItemViewIndex:_firstItemViewIndex];
    }
    // reload visible views
    NSUInteger i = _firstItemViewIndex;
    while (i < _numberOfItems
           && _idxToItemView.count < _maxNumberOfVisibleItems) {
        [self loadItemViewWithItemIndex:i CardexIndex:i - _firstItemViewIndex];
        i++;
    }
    if (_idxToItemView.count > 0) {
        [self setNeedsLayout];
    }
}

- (void)validateMaxNumberOfVisibleItems:(NSUInteger)maxNumberOfVisibleItems {
    NSAssert(maxNumberOfVisibleItems > 0,
             @"The number of visible items must be positive");
}

- (void)validateFirstItemViewIndex:(NSUInteger)firstItemViewIndex {
    NSAssert(firstItemViewIndex >= 0,
             @"The index of the first item view must be positive!");
    if (_dataSource) {
        NSAssert(firstItemViewIndex < _numberOfItems,
                 @"The index of the first item view \
                 must be smaller than the total number of items!");
    }
}

- (UIView *)loadItemViewWithItemIndex:(NSUInteger)itemIndex
                          CardexIndex:(NSInteger)cardexIndex {
    NSLog(@"loadItemViewWithItemIndex:CardexIndex:");
    UIView *containerView = [self dequeueItemView];
    UIView *reusingView = nil;
    if (containerView) {
        reusingView = [containerView.subviews lastObject];
        [reusingView removeFromSuperview];
    }
    UIView *view = [_dataSource cardexView:self
                        viewForItemAtIndex:itemIndex
                               reusingView:reusingView];
    if (view) {
        if (!containerView) {
            containerView = [[UIView alloc] initWithFrame:view.frame];
            containerView.backgroundColor = [UIColor orangeColor];
        } else {
            containerView.frame = view.frame;
        }
        
        _itemViewHeight = view.frame.size.height;
        _itemViewWidth = view.frame.size.width;
        [containerView addSubview:view];
        [_idxToItemView setObject:containerView
                           forKey:[NSNumber numberWithInteger:itemIndex]];
        [_contentView addSubview:containerView];
        view.alpha = .5;
        objc_setAssociatedObject(containerView,
                                 &cardexIndexKey,
                                 [NSNumber numberWithInteger:cardexIndex],
                                 OBJC_ASSOCIATION_RETAIN);
        return containerView;
    }
    return nil;
}

- (BOOL)tryAndLoadItemViewWithItemIndex:(NSUInteger)itemIndex
                            CardexIndex:(NSInteger)cardexIndex
                   dependsOnViewOfIndex:(NSInteger)anotherItemIndex {
    NSLog(@"loadItemViewWithItemIndex:CardexIndex:");
    UIView *containerView = [self dequeueItemView];
    UIView *reusingView = nil;
    if (containerView) {
        reusingView = [containerView.subviews lastObject];
        [reusingView removeFromSuperview];
    }
    UIView *view = [_dataSource cardexView:self
                        viewForItemAtIndex:itemIndex
                               reusingView:reusingView];
    if (view) {
        if (!containerView) {
            containerView = [[UIView alloc] initWithFrame:view.frame];
            containerView.backgroundColor = [UIColor orangeColor];
        } else {
            containerView.frame = view.frame;
        }
        
        _itemViewHeight = view.frame.size.height;
        _itemViewWidth = view.frame.size.width;
        view.alpha = .5;
        objc_setAssociatedObject(containerView,
                                 &cardexIndexKey,
                                 [NSNumber numberWithInteger:cardexIndex],
                                 OBJC_ASSOCIATION_RETAIN);
        [containerView addSubview:view];
        [self transformItemView:containerView
                        atIndex:itemIndex
           dependsOnViewOfIndex:anotherItemIndex];
        if ([self isOutOfBoundsOfCardexView:containerView]) {
            [self queueItemView:containerView];
            NSLog(@"fail to add item view %d", itemIndex);
        } else {
            [_idxToItemView setObject:containerView
                               forKey:[NSNumber numberWithInteger:itemIndex]];
            [_contentView addSubview:containerView];
            NSLog(@"succeed to add item view %d", itemIndex);
            return YES;
        }
    }
    return NO;
}

- (void)queueItemView:(UIView *)view {
    if (view) {
        [_itemViewPool addObject:view];
    }
}


- (UIView *)dequeueItemView {
    NSLog(@"dequeueItemView");
    UIView *view = [[_itemViewPool anyObject] retain];
    if (view) {
        [_itemViewPool removeObject:view];
    }
    return [view autorelease];
}

- (NSArray *)getSortedIndexes {
    NSLog(@"getSortedIndexes");
    return [[[_idxToItemView.allKeys
              sortedArrayUsingComparator:
              ^(NSNumber *obj1, NSNumber *obj2) {
                  if ([obj1 intValue] > [obj2 intValue]) {
                      return NSOrderedDescending;
                  }
                  if ([obj1 intValue] < [obj2 intValue]) {
                      return NSOrderedAscending;
                  }
                  return NSOrderedSame;
              }] retain] autorelease];
}

- (void)didPan:(UIPanGestureRecognizer *)panGestureRecognizer {
    NSLog(@"didPan:");
    switch (panGestureRecognizer.state) {
        case UIGestureRecognizerStateBegan: {
            _status = READY_TO_SCROLL;
            _previousTranslation =
            [panGestureRecognizer translationInView:self].y;
            if ([_delegate respondsToSelector:
                 @selector(cardexViewWillBeginDragging:)]) {
                [_delegate cardexViewWillBeginDragging:self];
            }
        }
            break;
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled: {
            _status = DECELERATING;
            if ([_delegate respondsToSelector:
                 @selector(cardexViewWillBeginDragging:)]) {
            }
            CGPoint velocity = [panGestureRecognizer velocityInView:self];
            _startVelocity = SPEED_UP_FACTOR
            * sqrtf(powf(velocity.x, 2) + powf(velocity.y, 2));
            if (velocity.y < 0) {
                _startVelocity = - _startVelocity;
            }
            [self startDecelerating];
        }
            break;
        default: {
            _status = SCROLLING_BY_DRAGGING;
            CGFloat curTranslation =
            [panGestureRecognizer translationInView:self].y;
            // actural scroll distance by the user's panning
            _scrollOffset = curTranslation - _previousTranslation;
            _previousTranslation = curTranslation;
            CGPoint velocity = [panGestureRecognizer velocityInView:self];
            _startVelocity = SPEED_UP_FACTOR
            * sqrtf(powf(velocity.x, 2) + powf(velocity.y, 2));
            if (velocity.y < 0) {
                _startVelocity = - _startVelocity;
            }
            [self dragging];
        }
            break;
    }
}

- (void)dragging {
    NSLog(@"dragging");
    if (_scrollOffset != .0f) {
        _startTime = CACurrentMediaTime();
        [self startAnimation];
    }
}

- (void)startAnimation {
    @synchronized(self) {
        if (_timer == nil) {
            _timer = [NSTimer scheduledTimerWithTimeInterval:_frameRate
                                                      target:self
                                                    selector:@selector(step)
                                                    userInfo:nil
                                                     repeats:YES];
        }
 
    }
}

- (void)stopAnimation {
    @synchronized(self) {
        [_timer invalidate];
        _timer = nil;
    }
}

- (void)scrollByOffset:(CGFloat)offset {
    NSArray *sortedIndexes = [self getSortedIndexes];
    NSAssert(sortedIndexes != nil, @"Sorted Indexes is nil!");
    if (_startVelocity > 0) {
        UIView *lastItemView = [_idxToItemView objectForKey:
                                [sortedIndexes lastObject]];
        CGFloat diff = _firstItemViewOrigin.y - lastItemView.frame.origin.y;
        NSAssert(offset >= 0, @"offset < 0");
        if (diff < offset) {
            offset = diff;
        }
    } else if (_startVelocity < 0) {
        UIView *firstItemView = [_idxToItemView objectForKey:
                                 [sortedIndexes objectAtIndex:0]];
        CGFloat diff = ABS(_firstItemViewOrigin.y - firstItemView.frame.origin.y);
        NSAssert(offset <= 0, @"offset > 0");
        if (diff < ABS(offset)) {
            offset = -diff;
        }
    }
    BOOL shouldStop = NO;
    if (offset != .0f) {
        int minItemIndex = _numberOfItems;
        for (NSNumber *n in _idxToItemView.allKeys) {
            UIView *v = [_idxToItemView objectForKey:n];
            [self transformItemView:v withOffset:offset];
            if ([n integerValue] < minItemIndex) {
                minItemIndex = [n integerValue];
            }
        }
        NSAssert(minItemIndex != _numberOfItems,
                 @"Can't get minItemIndex when scrolling!");
        if (_startVelocity < 0 && minItemIndex > 0) {
            UIView *v = [_idxToItemView objectForKey:
                         [NSNumber numberWithInteger:minItemIndex]];
            int minCardexIndex = [objc_getAssociatedObject(v, &cardexIndexKey)
                                  integerValue];
            BOOL try = YES;
            for (int i = minItemIndex - 1; i >= 0 && try; i--) {
                try = [self tryAndLoadItemViewWithItemIndex:i
                                                CardexIndex:--minCardexIndex
                                       dependsOnViewOfIndex:i + 1];
            }
        }
        CGFloat oldScrollOffset = _scrollOffset;
        _scrollOffset -= offset;
        if (oldScrollOffset * _scrollOffset <= .0f) {
            shouldStop = YES;
        }
    } else {
        shouldStop = YES;
    }
    if (shouldStop) {
        _lastStepTime = 0;
        _status = STOP;
        [self stopAnimation];
        [self loadUnloadViewsByScrollDirection:(_startVelocity > 0 ? YES : NO)];
    }
}

- (void)loadUnloadViewsByScrollDirection:(BOOL)removeFront {
    @synchronized(self) {
        if (removeFront) {
            // remove the view out of bounds of the content view
            NSMutableArray *toRemove = [NSMutableArray array];
            for (NSNumber *n in _idxToItemView.allKeys) {
                UIView *v = [_idxToItemView objectForKey:n];
                if ([self isOutOfBoundsOfCardexView:v]) {
                    [toRemove addObject:n];
                    [v removeFromSuperview];
                }
            }
            if (toRemove.count > 0) {
                for (NSNumber *n in toRemove) {
                    UIView *v = [_idxToItemView objectForKey:n];
                    [_idxToItemView removeObjectForKey:n];
                    [self queueItemView:v];
                }

                // update the cardex indexes
                int maxItemIndex = -1;
                NSArray *sortedIndexes = [self getSortedIndexes];
                for (NSNumber *itemIndex in sortedIndexes) {
                    UIView *v = [_idxToItemView objectForKey:itemIndex];
                    int diff = [itemIndex intValue]
                    - [[sortedIndexes objectAtIndex:0] integerValue];
                    objc_setAssociatedObject(v,
                                             &cardexIndexKey,
                                             [NSNumber numberWithInteger:
                                              diff],
                                             OBJC_ASSOCIATION_RETAIN);
                    if ([itemIndex integerValue] > maxItemIndex) {
                        maxItemIndex = [itemIndex integerValue];
                    }
                }
                
                // add new views
                int itemIndexToAdd = maxItemIndex + 1;
                while (_idxToItemView.count < _maxNumberOfVisibleItems
                       && itemIndexToAdd < _numberOfItems) {
                    UIView *pv =
                    [_idxToItemView objectForKey:
                     [NSNumber numberWithInteger:itemIndexToAdd - 1]];
                    int cardexIndex =
                    [objc_getAssociatedObject(pv, &cardexIndexKey)
                     integerValue] + 1;
                    UIView *v =
                    [self loadItemViewWithItemIndex:itemIndexToAdd
                                        CardexIndex:cardexIndex];
                    [self transformItemView:v
                                    atIndex:itemIndexToAdd
                       dependsOnViewOfIndex:itemIndexToAdd - 1];
                    itemIndexToAdd++;
                }
            }
        } else {
            NSArray *sortedIndexes = [self getSortedIndexes];
            if (_idxToItemView.count > _maxNumberOfVisibleItems) {
                int i = [[sortedIndexes lastObject] integerValue];
                while (i >= 0
                       && _idxToItemView.count > _maxNumberOfVisibleItems) {
                    NSNumber *itemIndex = [NSNumber numberWithInteger:i];
                    UIView *v = [_idxToItemView objectForKey:itemIndex];
                    [v removeFromSuperview];
                    [_idxToItemView removeObjectForKey:itemIndex];
                    [self queueItemView:v];
                    i--;
                }
            }
            for (NSNumber *itemIndex in _idxToItemView.allKeys) {
                UIView *v = [_idxToItemView objectForKey:itemIndex];
                int diff = [itemIndex intValue]
                - [[sortedIndexes objectAtIndex:0] integerValue];
                objc_setAssociatedObject(v,
                                         &cardexIndexKey,
                                         [NSNumber numberWithInteger:
                                          diff],
                                         OBJC_ASSOCIATION_RETAIN);
            }
        }
    }
}

- (void)step {
    NSLog(@"step");
    NSTimeInterval currentTime = CACurrentMediaTime();
    if (_lastStepTime == 0) {
        _lastStepTime = _startTime;
    }
    CGFloat offset = .0f;
    switch (_status) {
        case SCROLLING_BY_DRAGGING: {
            // Uniform rectilinear motion
            NSLog(@"SCROLLING_BY_DRAGGING");
            offset = _startVelocity * (currentTime - _lastStepTime);
        }
            break;
        case DECELERATING: {
            // Newton's second Law
            CGFloat time = MIN(_decelerationDuration,
                               currentTime - _lastStepTime);
            CGFloat acceleration = -_startVelocity / _decelerationDuration;
            offset = _startVelocity * time
            + .5f * acceleration * powf(time, 2);
        }
            break;
        default:
            break;
    }
    _lastStepTime = currentTime;
    [self scrollByOffset:offset];
}

- (BOOL)isOutOfBoundsOfCardexView:(UIView *)view {
    //NSLog(@"isOutOfBoundsOfCardexView:");
    if (view.frame.origin.y > _contentView.frame.size.height
        || view.frame.origin.y <= 0) {
        return YES;
    }
    return NO;
}

- (BOOL)shouldDecrementFirstItemIndex {
    NSLog(@"shouldDecrementFirstItemIndex");
    UIView *testView = [[UIView alloc] initWithFrame:
                        CGRectMake(0, 0, _itemViewWidth, _itemViewHeight)];
    [self transformItemView:testView
                    atIndex:_firstItemViewIndex - 1
       dependsOnViewOfIndex:_firstItemViewIndex];
    if (testView.frame.origin.y < _contentView.frame.size.height) {
        return YES;
    }
    return NO;
}

- (void)transformItemView:(UIView *)view atIndex:(NSInteger)index {
    NSLog(@"transformItemView:atIndex:");
    if ([_dataSource respondsToSelector:@selector(firstItemViewCenter:)]) {
        view.frame = CGRectMake(0, 0,
                                _itemViewWidth, _itemViewHeight);
        view.center = [_dataSource firstItemViewCenter:self];
    } else {
        view.frame = CGRectMake((_contentView.frame.size.width
                                 - _itemViewWidth) / 2,
                                _contentView.frame.size.height
                                - _itemViewHeight * 1.0f,
                                _itemViewWidth, _itemViewHeight);
    }
    CATransform3D transform = CATransform3DIdentity;
    transform.m34 = _perspective;
    transform = CATransform3DRotate(transform, _gradient, 1, 0, 0);
    transform = CATransform3DTranslate(transform, 0, 0,
                                       - _itemViewHeight
                                       * _zOffsetRate * index);
    view.layer.transform = transform;
}


- (void)transformItemView:(UIView *)view withOffset:(CGFloat)offset {
    //NSLog(@"transformItemView:withOffset:");
    if ([_dataSource respondsToSelector:@selector(firstItemViewCenter:)]) {
        view.frame = CGRectMake(0, 0,
                                _itemViewWidth, _itemViewHeight);
        view.center = [_dataSource firstItemViewCenter:self];
    } else {
        view.frame = CGRectMake((_contentView.frame.size.width
                                 - _itemViewWidth) / 2,
                                _contentView.frame.size.height
                                - _itemViewHeight * 1.0f,
                                _itemViewWidth, _itemViewHeight);
    }
    CATransform3D transform = view.layer.transform;
    transform = CATransform3DTranslate(transform, 0, 0, offset);
    view.layer.transform = transform;
}

- (void)transformItemView:(UIView *)view
                  atIndex:(NSInteger)index
     dependsOnViewOfIndex:(NSInteger)anIndex {
    NSLog(@"transformItemView:atIndex:dependsOnViewOfIndex:");
    UIView *dv = [_idxToItemView objectForKey:
                  [NSNumber numberWithInteger:anIndex]];
    if (dv) {
        if ([_dataSource respondsToSelector:@selector(firstItemViewCenter:)]) {
            view.frame = CGRectMake(0, 0,
                                    _itemViewWidth, _itemViewHeight);
            view.center = [_dataSource firstItemViewCenter:self];
        } else {
            view.frame = CGRectMake((_contentView.frame.size.width
                                     - _itemViewWidth) / 2,
                                    _contentView.frame.size.height
                                    - _itemViewHeight * 1.0f,
                                    _itemViewWidth, _itemViewHeight);
        }
        CATransform3D transform = dv.layer.transform;
        int indexDiff = index - anIndex;
        transform =
        CATransform3DTranslate(transform, 0, 0,
                               -_itemViewHeight * _zOffsetRate *indexDiff);
        view.layer.transform = transform;
    } else {
        NSAssert(dv != nil, @"transformItemView:atIndex:dependsOnViewOfIndex:\
                 dependent view is nil!");
    }
}

- (CGFloat)decelerationDistance {
    CGFloat acceleration = -_startVelocity * DECELERATION_FACTOR
    * (1.0f - _decelerationRate);
    return -powf(_startVelocity, 2.0f) / (2.0f * acceleration);
}

- (void)startDecelerating {
    int distance = [self decelerationDistance];
    _scrollOffset = distance;
    _startTime = CACurrentMediaTime();
    _decelerationDuration = ABS(distance) / ABS(.5f * _startVelocity);
    if (_scrollOffset != .0f) {
        [self stopAnimation];
        [self startAnimation];
    }
}

@end