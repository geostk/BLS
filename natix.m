function [ tmp tmp2 tmp3 ] = natix(image_id, wideness, similarity_treshold, amount, blur_size)

%%% Wczytywanie obrazu

fprintf('# Loading an image\n');

cube = hyper_ncube(image_id);
ground_truth = hyper_class(image_id);
depth = size(cube, 3);
pixel_count = numel(cube) / depth;

imshow(false_color(cube));
imwrite(false_color(cube), 'false_color.png');
title('False-color image');
pause(.125);

%%% Detekcja granic

fprintf('# Border detection\n');

edges_cube = fedges_cube(cube, wideness);

subplot 132;
imshow(mean(edges_cube,3));
imwrite(mean(edges_cube,3), 'edges_cube.png');
title('Flattered borders cube');
pause(.125);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%
%%% Filtering
%%%
fprintf('# Filtering\n');

filter = ffilter(edges_cube);

tmp = filter;

subplot 131;
imshow(mean(edges_cube,3));
title('Before');

edges_cube = edges_cube(:,:,filter);

mean_edges = max(edges_cube,[],3);

imwrite(mean_edges,'filtered_mean_edges.png');

mean_edges = anisodiff2D(mean_edges,blur_size,1/7,2,1);

imwrite(mean_edges,'aniso_mean_edges.png');

cube = cube(:,:,filter);
depth = size(cube,3);

subplot 132;
imshow(mean(edges_cube,3));
title('After');

edges_treshold = mean(mean(mean_edges));
edges_mask = mean_edges > edges_treshold;

subplot 133;
imshow(edges_mask);
title('Mask');

imwrite(edges_mask,'edges_mask.png');

pause(5.125);

%%% Filling

fprintf('# Filling\n');
% http://www.mathworks.com/help/images/ref/imfill.html
% http://blogs.mathworks.com/steve/2008/08/05/filling-small-holes/
negative = imcomplement(edges_mask);
filled = imfill(negative, 'holes');
holes = filled & ~negative;
bigholes = bwareaopen(holes, 200);
smallholes = holes & ~bigholes;
new = negative | smallholes;

subplot 131;
imshow(negative);
title('1');
subplot 132;
imshow(filled);
title('2');
subplot 133;
imshow(new);
imwrite(new,'new.png');
title('3');
pause(.125);

%%% Labelling
fprintf('# Labelling\n');

labels = bwlabel(new);
labels_no = max(max(labels));

fprintf('%i labels\n', labels_no);

subplot 131;
imshow(label2rgb(labels));
imwrite(label2rgb(labels), 'region_labels.png');
title('Region labels');
pause(.125);

%%% Remove all small regions
one_percent = (size(labels,1)*size(labels,2)) / amount;
for label = 1:labels_no
    amount = sum(sum(labels==label));
    if amount < one_percent
        labels(labels==label) = 0;
    end
end

subplot 132;
imshow(label2rgb(labels));
title('Cut off the small regions');
pause(.125);

%%% Remap

fprintf('# Remap');
labels = remap(labels);
fprintf('.\n');
labels_no = max(max(labels));
fprintf('%i labels\n', labels_no);

subplot 133;
imshow(label2rgb(labels));
title('Remap');
pause(.125);


%%% Signature merging

fprintf('# Signature merging\n');
tmp = cube;
flattern_cube = reshape(cube,pixel_count,depth);

for i=1:labels_no
    mask = labels == i;
    flattern_mask = reshape(mask,pixel_count,1);
    masked = flattern_cube(flattern_mask,:);
    signature = mean(masked);
      
    for j=1:(i-1)
       another_mask = labels == j;
       another_flattern_mask = reshape(another_mask,pixel_count,1);
       another_signature = mean(flattern_cube(another_flattern_mask,:));
       
       distance = mean(abs(signature-another_signature));
       
       if(distance < similarity_treshold)
           labels(labels==i) = j;
           break;
       end
    end   
end

subplot 132;
imshow(label2rgb(labels));

title('Merged signatures');
pause(.125);

labels = remap(labels);
subplot 133;
imshow(label2rgb(labels));
imwrite(label2rgb(labels),'merged_signatures.png');

title('Remap');
pause(.125);

labels_no = max(max(labels));

fprintf('%i labels\n', labels_no);
%%% Blurred labeling
foo = zeros(size(cube,1),size(cube,2),labels_no);
for label = 1:labels_no
    mask = labels == label;
    subplot 142;
    imshow(mask);
    filename = sprintf('mask_0_%i.png',label);
    imwrite(mask, filename);
    title(label);

    flattern_mask = reshape(mask, pixel_count, 1);
    masked = flattern_cube(flattern_mask,:);
    signature = mean(masked);

    subplot 141;
    plot(signature);
    ylim([0 1]);
    title('Signature');

    distance = abs(bsxfun(@minus,flattern_cube,signature));
    layer = reshape(distance,size(cube,1),size(cube,2),[]);
    
    layer = 1-max(layer,[],3);

    layer(layer < .9) = layer(layer < .9) / 3;
    % Or diff?
    layer2 = anisodiff2D(layer,blur_size,1/7,30,2);
    foo(:,:,label) = layer;

    subplot 143;
    imshow(layer);
    filename = sprintf('mask_1_%i.png',label);
    imwrite(layer, filename);

    subplot 144;
    imshow(layer2);
    filename = sprintf('mask_2_%i.png',label);
    imwrite(layer2, filename);
    pause(.125);

    tmp = layer;
    tmp2 = layer2;
    tmp3 = 0;
    foo(:,:,label) = layer2;
end

[ saturation hue ] = max(foo,[],3); 
%tmp = foo;
%tmp2 = saturation;
%tmp3 = hue;

hsv_image = ones(size(cube,1), size(cube,2), 3);
hsv_image(:,:,1) = hue / labels_no;
hsv_image(:,:,3) = max(cube,[],3);
hsv_image(:,:,3) = hsv_image(:,:,3)*.7;%saturation;

rgb_image = hsv2rgb(hsv_image);

subplot 131;
imshow(label2rgb(hue));
imwrite(label2rgb(hue), 'hue.png');
labels_no = max(max(hue));
index = labels_no + 1;

% Analizujemy każdą etykietę
% Jeśli ma rozłączne elementy, odrzucamy każdy mniejszy niż jeden procent obrazu
% A z wszystkich pozostałych tworzymy nowe etykiety
for label = 1:labels_no

    mono = zeros(size(hue));
    mono(hue==label) = 1;
    mono_lab = bwlabel(mono);
    explode_no = max(max(mono_lab));

    for i = 1:explode_no
        amount = sum(sum(mono_lab==i));
        if amount < one_percent
            hue(mono_lab==i) = 0;
            mono_lab(mono_lab==i) = 0;
        else
            fprintf('\tnew layer[%i]\n', index);
            hue(mono_lab==i) = index;
            index = index + 1;
        end
    end
    fprintf('\tlabel %i\n', label, explode_no);
    
    
    subplot 132;
    imshow(mono);

    subplot 133;
    imshow(label2rgb(mono_lab));

    subplot 131;
    imshow(label2rgb(hue));

    pause(.125);
end

%tmp = rgb_image;
%tmp2 = ground_truth;

imwrite(label2rgb(hue), 'separated.png');

pause(.125);

subplot 141;
imshow(label2rgb(hue));

% Przyłączenie etykiet z ground truth
%{
learning_labels = hue;
c = hue;
c(ground_truth == 0) = 0;
subplot 142;
imshow(label2rgb(c));

labels_no = max(max(hue));
for label = 1:labels_no
    A = mode(ground_truth(c==label));
    fprintf('\tlabel %i = %i\n', label, A);
    c(c==label) = A;

    subplot 143;
    %imshow(

    %pause(3);
end
tmp = hue;
tmp2 = ground_truth;

subplot 143;
imshow(label2rgb(ground_truth));
subplot 144;
imshow(label2rgb(c));

imwrite(label2rgb(learning_labels), 'gg.png');

pause(.125)

labels_no = max(max(hue));
hsv_image(:,:,1) = hue/labels_no;

rgb_image = hsv2rgb(hsv_image);
%}
%%% Signature-neighbour merging
hue = remap(hue);
labels_no = max(max(hue));


subplot 132;
imshow(label2rgb(hue));
subplot 133;
imshow(label2rgb(ground_truth));
for label = 2:labels_no
    mono = hue == label;
    flattern_mono = reshape(mono,pixel_count,1);
    masked = flattern_cube(flattern_mono,:);
    signature = mean(masked);

%    a = ones([100 100]);
%    a(1:50,:) = label;
%    a(1,1) = labels_no;
%    a(1,2) = 1;

    for label_second = label-1:-1:1
        mono_second = hue == label_second;
        flattern_mono = reshape(mono_second,pixel_count,1);
        masked = flattern_cube(flattern_mono,:);
        signature_second = mean(masked);

 %       a(51:100,:) = label_second;

 %       subplot 131;
 %       imshow(label2rgb(a));
 %       pause(0.00001);


        stereo = mono + mono_second;
        stereo = bwlabel(stereo);

        regions_no = max(max(stereo));


        if(regions_no == 1)
            distance = mean(abs(signature-signature_second));
            if(distance<similarity_treshold)
                fprintf('[%ivs%i] MERGE!\n', label, label_second);
                hue(hue==label_second) = label;
                subplot 132;
                imshow(label2rgb(hue));
                pause(.125);
            end
        end
%        pause(.25);
    end


end

subplot 131;
imshow(label2rgb(hue));
imwrite(label2rgb(hue), 'region_merging.png');
title('Visum!');

e = hue;
e(ground_truth==0)=0;
subplot 132;
imshow(label2rgb(e));

subplot 133;
imshow(label2rgb(ground_truth));
title('GT');


imwrite(rgb_image,'visum.png');
