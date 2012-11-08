//
//  CardexViewController.m
//  Lib
//
//  Created by lingguang1997 on 10/29/12.
//  Copyright (c) 2012 lingguang1997. All rights reserved.
//

#import "Cardex.h"

@interface CardexViewController ()

@end

@implementation CardexViewController
@synthesize cardexView = _cardexView;
@synthesize dataItems = _dataItems;

- (id)initWithNibName:(NSString *)nibNameOrNil
               bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    self.cardexView = [[CardexView alloc] initWithFrame:self.view.bounds];
    [self.view addSubview:_cardexView];
    [_cardexView release];

    //Dummy Data
    self.dataItems = [NSMutableArray arrayWithCapacity:10];
    for (int i = 0; i < 30; i++) {
        [_dataItems addObject:[NSNumber numberWithInteger:i]];
    }
    //_cardexView.firstItemViewIndex = 10;

    _cardexView.dataSource = self;
    _cardexView.perspective =-0.001;
    _cardexView.maxNumberOfVisibleItems = 15;
    _cardexView.backgroundColor = [UIColor yellowColor];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (NSUInteger)numberOfItemsInCardexView:(CardexView *)cardexView {
    if (_dataItems) {
        return [_dataItems count];
    }
    return 0;
}

- (UIView *)cardexView:(CardexView *)cardexView
    viewForItemAtIndex:(NSUInteger)index
           reusingView:(UIView *)view {
    if (_dataItems == nil) {
        return nil;
    }
    if (view == nil) {
        UIImage *image = [UIImage imageNamed:@"img1.png"];
        UIImageView *imageView = [[[UIImageView alloc] initWithImage:image] autorelease];
        imageView.frame = CGRectMake(0, 0, 500, 500);
        UILabel *lbl = [[[UILabel alloc] initWithFrame:CGRectMake(0, 0, 500, 500)]
                        autorelease];
        lbl.textAlignment = NSTextAlignmentCenter;
        view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 500, 500)];
        [view addSubview:imageView];
        [view addSubview:lbl];
    }
    
    UILabel *lbl = [view.subviews lastObject];
    lbl.text = [NSString stringWithFormat:@"%d", [[_dataItems objectAtIndex:index] intValue]];
    lbl.backgroundColor = [UIColor orangeColor];
    lbl.alpha = .5;
    return view;
}

//- (CGPoint)firstItemViewCenter:(CardexView *)cardexView {
//    return CGPointMake(cardexView.frame.size.width / 2, cardexView.frame.size.height / 2);
//}

- (NSUInteger)firstItemIndexInCardexView:(CardexView *)cardexView {
    return 10;
}


- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	return YES;
}

@end
