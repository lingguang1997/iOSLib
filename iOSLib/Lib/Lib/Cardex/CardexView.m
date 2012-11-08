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

static const NSUInteger DEFAULT_ITEM_VIEW_POOL_CAPACITY = 20;
static const CGFloat DEFAULT_START_VELOCITY_THRESHHOLD = 30.0f;

void *cardexIndexKey, *itemIndexKey;

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
- (void)didPress:(UILongPressGestureRecognizer *)longPressGestureRecognizer;
- (void)didTap:(UITapGestureRecognizer *)tapGestureRecognizer;
- (void)dragging;
- (void)step;
- (BOOL)isOutOfBoundsOfCardexView:(UIView *)view;
- (void)transformItemView:(UIView *)view withOffset:(CGFloat)offset;
- (void)transformItemView:(UIView *)view
                  atIndex:(NSInteger)index
     dependsOnViewOfIndex:(NSInteger)anIndex;
- (CGFloat)decelerationDistance;
- (void)startDecelerating;
- (void)scrollByOffset:(CGFloat)offset;
- (void)didScroll:(BOOL)removeFront;
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
    @synchronized(self) {
        if (_timer) {
            [self stopAnimation];
            if ([_delegate respondsToSelector:@selector(cardexViewDidEndScrollingAnimation:)]) {
                [_delegate cardexViewDidEndScrollingAnimation:self];
            }
        }
    }
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
    NSLog(@"Pls make sure your look down at the \
          cardexes from the front to the end");
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
    int cardexIndex = 0;
    for (NSNumber *n in sortedIndexes) {
        UIView *v = [_idxToItemView objectForKey:n];
        [self transformItemView:v atIndex:cardexIndex];
        if (cardexIndex == 0) {
            _firstItemViewOrigin = v.frame.origin;
        }
        cardexIndex++;
    }
}

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
    _contentView.backgroundColor = [UIColor clearColor];
    
    UIPanGestureRecognizer *panGR =
    [[UIPanGestureRecognizer alloc] initWithTarget:self
                                            action:@selector(didPan:)];
    panGR.delegate = self;
    [_contentView addGestureRecognizer:panGR];
    [panGR release];
    UILongPressGestureRecognizer *pressGR =
    [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(didPress:)];
    pressGR.minimumPressDuration = .1f;
    [_contentView addGestureRecognizer:pressGR];
    [pressGR release];
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
         @selector(maxNumberOfVisibleItemsInCardexView:)]) {
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
            containerView = [[[UIView alloc] initWithFrame:view.frame]
                             autorelease];
            UITapGestureRecognizer *tapGR = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(didTap:)];
            tapGR.delegate = self;
            [containerView addGestureRecognizer:tapGR];
            [tapGR release];
        } else {
            containerView.layer.transform = CATransform3DIdentity;
            containerView.frame = view.frame;
        }
        containerView.backgroundColor = [UIColor clearColor];
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
        objc_setAssociatedObject(containerView,
                                 &itemIndexKey,
                                 [NSNumber numberWithInteger:itemIndex],
                                 OBJC_ASSOCIATION_RETAIN);
        return containerView;
    }
    return nil;
}

- (BOOL)tryAndLoadItemViewWithItemIndex:(NSUInteger)itemIndex
                            CardexIndex:(NSInteger)cardexIndex
                   dependsOnViewOfIndex:(NSInteger)anotherItemIndex {
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
            containerView = [[[UIView alloc] initWithFrame:view.frame]
                             autorelease];
            containerView.backgroundColor = [UIColor clearColor];
            UITapGestureRecognizer *tapGR = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(didTap:)];
            tapGR.delegate = self;
            [containerView addGestureRecognizer:tapGR];
            [tapGR release];
        } else {
            containerView.layer.transform = CATransform3DIdentity;
            containerView.frame = view.frame;
        }
        containerView.backgroundColor = [UIColor clearColor];

        _itemViewHeight = view.frame.size.height;
        _itemViewWidth = view.frame.size.width;
        view.alpha = .5;
        objc_setAssociatedObject(containerView,
                                 &cardexIndexKey,
                                 [NSNumber numberWithInteger:cardexIndex],
                                 OBJC_ASSOCIATION_RETAIN);
        objc_setAssociatedObject(containerView,
                                 &itemIndexKey,
                                 [NSNumber numberWithInteger:itemIndex],
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
            //[_contentView addSubview:containerView];
            UIView *anotherView = [_idxToItemView objectForKey:
                                   [NSNumber numberWithInteger:anotherItemIndex]];
            if (itemIndex < anotherItemIndex) {
                [_contentView insertSubview:containerView aboveSubview:anotherView];
            } else {
                [_contentView insertSubview:containerView belowSubview:anotherView];
            }
            NSLog(@"add a new view %@", _idxToItemView);
            NSLog(@"succeed to add item view %d", itemIndex);
            return YES;
        }
    }
    return NO;
}

- (void)queueItemView:(UIView *)view {
    if (view) {
        if (_itemViewPool.count < DEFAULT_ITEM_VIEW_POOL_CAPACITY) {
            [_itemViewPool addObject:view];
        }
    }
}


- (UIView *)dequeueItemView {
    UIView *view = [[_itemViewPool anyObject] retain];
    if (view) {
        [_itemViewPool removeObject:view];
    }
    return [view autorelease];
}

- (NSArray *)getSortedIndexes {
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
            CGPoint velocity = [panGestureRecognizer velocityInView:self];
            _startVelocity = SPEED_UP_FACTOR
            * sqrtf(powf(velocity.x, 2) + powf(velocity.y, 2));
            if (velocity.y < 0) {
                _startVelocity = - _startVelocity;
            }
            if ([_delegate respondsToSelector:
                 @selector(cardexViewDidEndDragging:willDecelerate:)]) {
                [_delegate cardexViewDidEndDragging:self
                                     willDecelerate:
                 _startVelocity == .0f ? NO : YES];
            }
            if (_startVelocity != 0) {
                if ([_delegate respondsToSelector:
                     @selector(cardexViewWillBeginDecelerating:)]) {
                }
            }
            [self startDecelerating];
        }
            break;
        case UIGestureRecognizerStateChanged: {
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
            @synchronized(self) {
                if (_timer != nil) {
                    if ([_delegate respondsToSelector:@selector(cardexViewWillBeginScrollingAnimation:)]) {
                        [_delegate cardexViewWillBeginScrollingAnimation:self];
                    }
                }
            }
            [self dragging];
        }
            break;
        default:
            break;
    }
}

- (void)didPress:(UILongPressGestureRecognizer *)longPressGestureRecognizer {
    _status = STOP;
    [self stopAnimation];
    if ([_delegate respondsToSelector:@selector(cardexViewDidEndScrollingAnimation:)]) {
        [_delegate cardexViewDidEndScrollingAnimation:self];
    }
}

- (void)didTap:(UITapGestureRecognizer *)tapGestureRecognizer {
    UIView *v = ((UIView *)[tapGestureRecognizer.view.subviews lastObject]).superview;
    NSUInteger itemIndex = [objc_getAssociatedObject(v, &itemIndexKey) integerValue];
    v.backgroundColor = [UIColor redColor];
    if ([_delegate respondsToSelector:
         @selector(cardexView:didSelectItemAtIndex:)]) {
        [_delegate cardexView:self didSelectItemAtIndex:itemIndex];
    }
}

- (void)dragging {
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
    // restrict the first and last item view's position
    NSLog(@"================");
    NSLog(@"startVelocity=%f", _startVelocity);
    NSLog(@"%@", _idxToItemView);

    if (_startVelocity > 0) {
        NSNumber *itemIndex = [sortedIndexes lastObject];
        if ([itemIndex integerValue] == _numberOfItems - 1) {
            UIView *lastItemView = [_idxToItemView objectForKey:itemIndex];
            CGFloat diff = _firstItemViewOrigin.y - lastItemView.frame.origin.y;
            
            NSAssert(offset >= 0, @"offset < 0");
            if (diff < offset) {
                offset = diff;
            }
        }
    } else if (_startVelocity < 0) {
        NSNumber *itemIndex = [sortedIndexes objectAtIndex:0];
        if ([itemIndex integerValue] == 0) {
            UIView *firstItemView = [_idxToItemView objectForKey:itemIndex];
            CGFloat diff = firstItemView.frame.origin.y - _firstItemViewOrigin.y;
            NSAssert(diff >= 0, @"_startVelocity<0, diff < 0");
            NSAssert(offset <= 0, @"offset > 0");
            if (diff < -offset) {
                offset = -diff;
            }
        }
    }
    BOOL shouldStop = NO;
    CGFloat oldScrollOffset = 0;
    if (offset != .0f) {
        int minItemIndex = _numberOfItems;
        int maxItemIndex = -1;
        // scroll each item view
        for (NSNumber *n in _idxToItemView.allKeys) {
            UIView *v = [_idxToItemView objectForKey:n];
            [self transformItemView:v withOffset:offset];
            if ([n integerValue] < minItemIndex) {
                minItemIndex = [n integerValue];
            }
            if ([n integerValue] > maxItemIndex) {
                maxItemIndex = [n integerValue];
            }
        }
        
        NSAssert(minItemIndex != _numberOfItems,
                 @"Can't get minItemIndex when scrolling!");
        // check if need to add item views
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
        if (_startVelocity > 0 && maxItemIndex < _numberOfItems - 1) {
            UIView *v = [_idxToItemView objectForKey:
                         [NSNumber numberWithInteger:maxItemIndex]];
            int maxCardexIndex = [objc_getAssociatedObject(v, &cardexIndexKey)
                                  integerValue];
            BOOL try = YES;
            for (int i = maxItemIndex + 1, j = minItemIndex;
                 i < _numberOfItems && try;
                 i++, j++) {
                if ([self isOutOfBoundsOfCardexView:
                     [_idxToItemView objectForKey:
                      [NSNumber numberWithInteger:j]]]) {
                    try = [self tryAndLoadItemViewWithItemIndex:i
                                                    CardexIndex:++maxCardexIndex
                                           dependsOnViewOfIndex:i - 1];
                } else {
                    try = NO;
                }
            }
        }

        [self didScroll:(_startVelocity > 0 ? YES : NO)];

        if ([_delegate respondsToSelector:@selector(cardexViewDidScroll:)]) {
            [_delegate cardexViewDidScroll:self];
        }
        // check if the scrolling is finished
        switch (_status) {
            case SCROLLING_BY_DRAGGING: {
                oldScrollOffset = _scrollOffset;
                _scrollOffset -= offset;
                if (oldScrollOffset * _scrollOffset <= .0f) {
                    shouldStop = YES;
                }
            }
                break;
            case DECELERATING: {
                CGFloat oldStartVelocity = _startVelocity;
                CGFloat diff = -_startVelocity / _decelerationDuration
                * (CACurrentMediaTime() - _lastStepTime);
                _startVelocity += diff;
                if (ABS(_startVelocity) < DEFAULT_START_VELOCITY_THRESHHOLD
                    || _startVelocity * oldStartVelocity < .0f) {
                    shouldStop = YES;
                }
            }
                break;
        }
    } else {
        shouldStop = YES;
    }
    if (shouldStop) {
        if (_status == DECELERATING) {
            if ([_delegate respondsToSelector:@selector(cardexViewDidEndDecelerating:)]) {
                [_delegate cardexViewDidEndDecelerating:self];
            }
        }
        _lastStepTime = 0;
        _status = STOP;
        [self stopAnimation];
        if ([_delegate respondsToSelector:@selector(cardexViewDidEndScrollingAnimation:)]) {
            [_delegate cardexViewDidEndScrollingAnimation:self];
        }
    }
}

- (void)didScroll:(BOOL)removeFront {
    NSArray *sortedIndexes = [self getSortedIndexes];
    // remove the item views
    if (removeFront) {
        if (_idxToItemView.count > _maxNumberOfVisibleItems) {
            int i = [[sortedIndexes objectAtIndex:0] integerValue];
            while (i < _numberOfItems
                   && _idxToItemView.count > _maxNumberOfVisibleItems) {
                NSNumber *itemIndex = [NSNumber numberWithInteger:i];
                UIView *v = [[_idxToItemView objectForKey:itemIndex] retain];
                [v removeFromSuperview];
                [_idxToItemView removeObjectForKey:itemIndex];
                [self queueItemView:[v autorelease]];
                i++;
            }
        }
    } else {
        if (_idxToItemView.count > _maxNumberOfVisibleItems) {
            int i = [[sortedIndexes lastObject] integerValue];
            while (i >= 0
                   && _idxToItemView.count > _maxNumberOfVisibleItems) {
                NSNumber *itemIndex = [NSNumber numberWithInteger:i];
                UIView *v = [[_idxToItemView objectForKey:itemIndex] retain];
                [v removeFromSuperview];
                [_idxToItemView removeObjectForKey:itemIndex];
                [self queueItemView:[v autorelease]];
                i--;
            }
        }
    }
    for (NSNumber *itemIndex in _idxToItemView.allKeys) {
        UIView *v = [[_idxToItemView objectForKey:itemIndex] retain];
        if ([self isOutOfBoundsOfCardexView:v]) {
            [v removeFromSuperview];
            [_idxToItemView removeObjectForKey:itemIndex];
            [self queueItemView:v];
        }
        [v autorelease];
    }

    
    // update the cardex indexes
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
    if ([_delegate respondsToSelector:@selector(cardexViewCurrentItemIndexDidChange:)]) {
        [_delegate cardexViewCurrentItemIndexDidChange:self];
    }

}

- (void)step {
    NSTimeInterval currentTime = CACurrentMediaTime();
    if (_lastStepTime == 0) {
        _lastStepTime = _startTime;
    }
    CGFloat offset = .0f;
    switch (_status) {
        case SCROLLING_BY_DRAGGING: {
            // Uniform rectilinear motion
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
            if (isnan(offset) || isinf(offset)
                || ABS(offset - (int)offset) >= 1) {
                offset = .0f;
            }
        }
            break;
        default:
            break;
    }
    _lastStepTime = currentTime;
    [self scrollByOffset:offset];
}

- (BOOL)isOutOfBoundsOfCardexView:(UIView *)view {
    CGFloat f = view.frame.origin.y;
    if (isnan(f) || isinf(f)
        || ABS(f - (int)f) >= 1) {
        return YES;
    }
    if (0 < f && f < _contentView.frame.size.height) {
        return NO;
    }
    return YES;
}

- (void)transformItemView:(UIView *)view atIndex:(NSInteger)index {
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
                 dependent view is nil!, itemIndex=%d, anotherIndex=%d",
                 index, anIndex);
    }
}

- (CGFloat)decelerationDistance {
    CGFloat acceleration = -_startVelocity * DECELERATION_FACTOR
    * (1.0f - _decelerationRate);
    return -powf(_startVelocity, 2.0f) / (2.0f * acceleration);
}

- (void)startDecelerating {
    int distance = [self decelerationDistance];
    _startTime = CACurrentMediaTime();
    _decelerationDuration = ABS(distance) / ABS(.5f * _startVelocity);
    [self startAnimation];
}

@end