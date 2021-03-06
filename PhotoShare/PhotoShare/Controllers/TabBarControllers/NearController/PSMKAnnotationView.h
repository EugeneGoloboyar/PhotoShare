//
//  PSMKAnnotationView.h
//  PhotoShare
//
//  Created by Евгений on 18.06.14.
//  Copyright (c) 2014 Eugene. All rights reserved.
//


@class PSMKAnnotationView;
@class PSMapAnnotation;

@protocol PSMKAnnotationViewDelegate

- (void)annotationView:(PSMKAnnotationView *)view didSelectAnnotation:(PSMapAnnotation *)annotation;

@end

@interface PSMKAnnotationView : MKAnnotationView

@property (nonatomic, weak) id<PSMKAnnotationViewDelegate> delegate;
@property (nonatomic, getter = isDetailViewHidden) BOOL detailViewHidden;

@end
