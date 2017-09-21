//
// UIViewController+StateViewController.m
// StateViewController
//
// Created by Pavol Kmet
// Copyright (c) 2017 GoodRequest (https://goodrequest.com)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "UIViewController+StateViewController.h"
#import "NSLayoutConstraint+StateViewController.h"
#import <objc/runtime.h>

static char const * const kContainerViewKey = "ContainerViewKey";
static char const * const kLoadingViewKey   = "LoadingViewKey";
static char const * const kEmptyViewKey     = "EmptyViewKey";
static char const * const kErrorViewKey     = "ErrorViewKey";
static char const * const kCurrentStateKey  = "CurrentStateKey";

@implementation UIViewController (StateViewController)

@dynamic containerView;
@dynamic loadingView;
@dynamic errorView;
@dynamic emptyView;
@dynamic currentState;

#pragma mark - Getter

- (UIView *)containerView
{
    UIView *containerView = (UIView *)objc_getAssociatedObject(self, kContainerViewKey);
    if (!containerView) {
        self.containerView = self.view;
        return self.view;
    }
    return containerView;
}

- (UIView *)loadingView
{
    return (UIView *)objc_getAssociatedObject(self, kLoadingViewKey);
}

- (UIView *)errorView
{
    return (UIView *)objc_getAssociatedObject(self, kErrorViewKey);
}

- (UIView *)emptyView
{
    return (UIView *)objc_getAssociatedObject(self, kEmptyViewKey);
}

- (StateViewControllerState)currentState
{
    return (StateViewControllerState)[objc_getAssociatedObject(self, kCurrentStateKey) unsignedIntegerValue];
}

#pragma mark - Setter

- (void)setContainerView:(UIView *)containerView
{
    objc_setAssociatedObject(self, kContainerViewKey, containerView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)setLoadingView:(UIView *)loadingView
{
    objc_setAssociatedObject(self, kLoadingViewKey, loadingView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)setErrorView:(UIView *)errorView
{
    objc_setAssociatedObject(self, kErrorViewKey, errorView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)setEmptyView:(UIView *)emptyView
{
    objc_setAssociatedObject(self, kEmptyViewKey, emptyView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)setCurrentState:(StateViewControllerState)currentState
{
    objc_setAssociatedObject(self, kCurrentStateKey, [NSNumber numberWithUnsignedInteger:currentState], OBJC_ASSOCIATION_COPY_NONATOMIC);
}

#pragma mark - State View Controller

- (BOOL)hasContent
{
    if ([self isKindOfClass:[UITableViewController class]]) {
        UITableViewController *controller = (UITableViewController *)self;
        return controller.tableView.numberOfSections > 0;
    } else if ([self isKindOfClass:[UICollectionViewController class]]) {
        UICollectionViewController *controller = (UICollectionViewController *)self;
        return controller.collectionView.numberOfSections > 0;
    }
    return NO;
}

- (UIEdgeInsets)insetForStateView:(UIView *)stateView
{
    return UIEdgeInsetsZero;
}

- (void)handleErrorWhenContentsAvailable:(NSError *)error
{
    
}

#pragma mark - Public

- (void)setupInitialState
{
    [self setupInitialStateCompletion:nil];
}

- (void)setupInitialStateCompletion:(void (^)(void))completion
{
    if (self.currentState == StateViewControllerStateLoading) {
        [self startLoadingAnimated:NO completion:completion];
    } else if (self.currentState == StateViewControllerStateError) {
        [self endLoadingAnimated:NO error:[NSError errorWithDomain:@"com.goodrequest.StateViewController" code:-1 userInfo:nil] completion:completion];
    } else {
        [self endLoadingAnimated:NO completion:completion];
    }
}

- (void)startLoadingAnimated:(BOOL)animated completion:(void (^)(void))completion
{
    if (![self hasContent]) {
        [self transitionToState:StateViewControllerStateLoading animated:animated completion:completion];
    }
}

- (void)endLoadingAnimated:(BOOL)animated completion:(void (^)(void))completion
{
    [self endLoadingAnimated:animated error:nil completion:completion];
}

- (void)endLoadingAnimated:(BOOL)animated error:(NSError *)error completion:(void (^)(void))completion
{
    if (error) {
        if ([self hasContent]) {
            [self handleErrorWhenContentsAvailable:error];
        } else {
            [self transitionToState:StateViewControllerStateError animated:animated completion:completion];
        }
    } else {
        if ([self hasContent]) {
            [self transitionToState:StateViewControllerStateContent animated:animated completion:completion];
        } else {
            [self transitionToState:StateViewControllerStateEmpty animated:animated completion:completion];
        }
    }
}

- (void)transitionToState:(StateViewControllerState)state animated:(BOOL)animated completion:(void (^)(void))completion
{
    if (self.currentState != state) {
        [self hideViewForState:self.currentState animated:animated completion:completion];
        [self showViewForState:state animated:animated completion:completion];
        self.currentState = state;
    } else {
        [self handleCompletion:completion];
    }
}

#pragma mark - Helper Methods

- (void)hideViewForState:(StateViewControllerState)state animated:(BOOL)animated completion:(void (^)(void))completion
{
    UIView *stateView = [self viewForState:state];
    if (stateView) {
        [self setStateView:stateView hidden:YES animated:animated completion:completion];
    }
}

- (void)showViewForState:(StateViewControllerState)state animated:(BOOL)animated completion:(void (^)(void))completion
{
    UIView *stateView = [self viewForState:state];
    if (stateView) {
        UIEdgeInsets insets = [self insetForStateView:stateView];
        
        stateView.alpha = animated ? 0 : 1;
        stateView.translatesAutoresizingMaskIntoConstraints = NO;
        
        if ([self.containerView isKindOfClass:[UITableView class]] || [self.containerView isKindOfClass:[UICollectionView class]]) {
            [self.containerView insertSubview:stateView atIndex:0];
        } else {
            [self.containerView addSubview:stateView];
        }
        
        // NECCESSARY FOR TABLE VIEW CONTROLLER AND COLLECTION VIEW CONTROLLER
        
        [[NSLayoutConstraint constraintWithItem:stateView attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:self.containerView
                                      attribute:NSLayoutAttributeHeight multiplier:1 constant:0] setPriority:800 isActive:YES];
        
        [[NSLayoutConstraint constraintWithItem:stateView attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:self.containerView
                                      attribute:NSLayoutAttributeWidth multiplier:1 constant:0] setPriority:800 isActive:YES];
        
        [[NSLayoutConstraint constraintWithItem:stateView attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:self.containerView
                                      attribute:NSLayoutAttributeCenterX multiplier:1 constant:0] setPriority:800 isActive:YES];
        
        [[NSLayoutConstraint constraintWithItem:stateView attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:self.containerView
                                      attribute:NSLayoutAttributeCenterY multiplier:1 constant:0] setPriority:800 isActive:YES];
        
        [[NSLayoutConstraint constraintWithItem:stateView attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:self.containerView
                                      attribute:NSLayoutAttributeTop multiplier:1 constant:insets.top] setPriority:999 isActive:YES];
        
        [[NSLayoutConstraint constraintWithItem:stateView attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:self.containerView
                                      attribute:NSLayoutAttributeBottom multiplier:1 constant:insets.bottom] setPriority:999 isActive:YES];
        
        [[NSLayoutConstraint constraintWithItem:stateView attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:self.containerView
                                      attribute:NSLayoutAttributeLeading multiplier:1 constant:insets.left] setPriority:999 isActive:YES];
        
        [[NSLayoutConstraint constraintWithItem:stateView attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual toItem:self.containerView
                                      attribute:NSLayoutAttributeTrailing multiplier:1 constant:insets.right] setPriority:999 isActive:YES];
        
        [self setStateView:stateView hidden:NO animated:animated completion:completion];
    }
}

- (UIView *)viewForState:(StateViewControllerState)state
{
    switch (state) {
        case StateViewControllerStateContent:
            return nil;
        case StateViewControllerStateLoading:
            return self.loadingView;
        case StateViewControllerStateError:
            return self.errorView;
        case StateViewControllerStateEmpty:
            return self.emptyView;
    }
}

- (void)setStateView:(UIView *)stateView hidden:(BOOL)hidden animated:(BOOL)animated completion:(void (^)(void))completion
{
    NSTimeInterval delay = hidden ? 0.4 : 0.0;
    
    void (^animations)(void) = ^{
        stateView.alpha = !hidden;
    };
    
    if (animated) {
        [UIView animateWithDuration:0.2 delay:delay options:UIViewAnimationOptionBeginFromCurrentState animations:animations completion:^(BOOL finished) {
            if (finished) {
                if (hidden) {
                    [stateView removeFromSuperview];
                }
                [self handleCompletion:completion];
            }
        }];
    } else {
        [UIView performWithoutAnimation:animations];
        if (hidden) {
            [stateView removeFromSuperview];
        }
        [self handleCompletion:completion];
    }
}

- (void)handleCompletion:(void (^)(void))completion
{
    if (completion) {
        completion();
    }
}

@end
