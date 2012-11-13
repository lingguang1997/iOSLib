//
//  Cardex.h
//  ControllerLib
//
//  Created by lingguang1997 on 11/3/12.
//  Copyright (c) 2012 lingguang1997. All rights reserved.
//

#define DEBUG_CARDEX 1

@class CardexView;

@protocol CardexDataSource <NSObject>

- (NSUInteger)numberOfItemsInCardexView:(CardexView *)cardexView;
- (UIView *)cardexView:(CardexView *)cardexView
    viewForItemAtIndex:(NSUInteger)index
           reusingView:(UIView *)view;

@optional
- (NSUInteger)maxNumberOfVisibleItemsInCardexView:(CardexView *)cardexView;
- (NSUInteger)firstItemIndexInCardexView:(CardexView *)cardexView;
- (CGPoint)firstItemViewCenter:(CardexView *)cardexView;

@end

@protocol CardexDelegate <NSObject>
@optional

- (void)cardexViewWillBeginScrollingAnimation:(CardexView *)cardexView;
- (void)cardexViewDidEndScrollingAnimation:(CardexView *)cardexView;
- (void)cardexViewDidScroll:(CardexView *)cardexView;
- (void)cardexViewCurrentItemIndexDidChange:(CardexView *)cardexView;
- (void)cardexViewWillBeginDragging:(CardexView *)cardexView;
- (void)cardexViewDidEndDragging:(CardexView *)cardexView
                  willDecelerate:(BOOL)decelerate;
- (void)cardexViewWillBeginDecelerating:(CardexView *)cardexView;
- (void)cardexViewDidEndDecelerating:(CardexView *)cardexView;

- (void)cardexView:(CardexView *)cardexView didSelectItemAtIndex:(NSInteger)index;

- (CGFloat)cardexViewItemWidth:(CardexView *)cardexView;
- (CATransform3D)cardexView:(CardexView *)cardexView itemTransformForOffset:(CGFloat)offset baseTransform:(CATransform3D)transform;

@end

@interface CardexView : UIView <UIGestureRecognizerDelegate> {
    @private
    id<CardexDataSource> _dataSource;
    id<CardexDelegate> _delegate;

    NSUInteger _maxNumberOfVisibleItems;
    NSUInteger _firstItemViewIndex;
    UIView *_contentView;

    CGFloat _zOffsetRate;
    CGFloat _perspective;
    CGFloat _gradient;
    CGFloat _decelerationRate;
}
@property (assign, nonatomic) id<CardexDataSource> dataSource;
@property (assign, nonatomic) id<CardexDelegate> delegate;
@property (assign, nonatomic) NSUInteger maxNumberOfVisibleItems;
@property (strong, nonatomic, readonly) UIView *contentView;
@property (assign, nonatomic) NSUInteger firstItemViewIndex;
@property (assign, nonatomic) CGFloat zOffsetRate;
@property (assign, nonatomic) CGFloat perspective;
@property (assign, nonatomic) CGFloat gradient;
@property (assign, nonatomic) CGFloat decelerationRate;


- (id)init;
- (id)initWithFrame:(CGRect)frame;
- (id)initWithCoder:(NSCoder *)aDecoder;
- (void)reloadData;

@end
