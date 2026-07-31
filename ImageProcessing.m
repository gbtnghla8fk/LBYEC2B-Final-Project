%=================================================
%Parameter estimation function for each stage of processing
%=================================================

function nIters = autoEstimateDenoiseStrength(app, img)
    noiseVar = max(0, mean2(stdfilt(img).^2));
    nIters = round(min(12, max(3, noiseVar*50)));

end

function sens = autoEstimateSensitivity(app, img);
    otsuLevel = graythresh(img);
    sens = min(0.7, max(0.3, otsuLevel * 1.1));
end

function [minArea, radius] = autoEstimateMorphParams(app, img)
    [numRows, numCols] = size(img);
    totalPixels = numRows * numCols;
    minArea = max(20, round(totalPixels * 0.0005));
    avgDim = mean([numRows, numCols]);
    radius = round(avgDim / 120);
end

%=================================================
% Main Image Processing Functions
%=================================================

%Denoising Stage(Speckle Reduction)
function denoisedImg = runDenoisingStage(app, inputImg, filterStrength)
denoisedImg = imdiffusefilt(inputImg, ...
    'GradientThreshold', 0.1, ...
    'NumberOfIterations', filterStrength);
end

%Segmentation Stage
function segMask = runSegmentationStage(app, denoisedImg, sensitivity)
    segMask = imbinarize(denoisedImg, 'adaptive', ...
                'Sensitivity', sensitivity, ...
                'ForegroundPolarity', 'bright');
end

%Morphological Cleaning
function cleanMask = runMorphologicalStage(app, binaryMask, minArea, radius)
    cleanMask = bwareaopen(binaryMask, minArea);
    se = strel('disk', radius);
    cleanMask = imclose(cleanMask, se);
    cleanMask = imfill(cleanMask, 'holes')
end

%Rendering Image
function renderVisualResults(App)
    app.FinalOutput = app.DenoisedData;
    app.FinalOutput(~app.BinaryMask) = 0;

    imshow(app.FinalOutput, 'Parent', app.ProcessedAxes);
    hold(app.ProcessedAxes, 'on');
    visboundaries(app.ProcessedAxes, app.BinaryMask, 'Color', 'yellow', 'LineWidth', 1.5);
    hold(app.ProcessedAxes, 'off');
    title(app.ProcessedAxes, 'Automated Segmented Target');
end

%% Master Pipeline Execution (Called directly by Load Callback)
function executeAutoPipeline(app)
    if isempty(app.RawImageData)
    return;
    end

    % --- Step 1: Program-Determined Parameter Calculation ---
    autoDenoiseIter = app.autoEstimateDenoiseStrength(app.RawImageData);
    autoSens = app.autoEstimateSensitivity(app.RawImageData);
    [autoMinArea, autoRadius] = app.autoEstimateMorphParams(app.RawImageData);

    % Update UI Labels to show calculated parameters to user
    app.DenoiseLabel.Text = sprintf('Filter Iterations: %d', autoDenoiseIter);
    app.SensLabel.Text    = sprintf('Sensitivity: %.2f', autoSens);
    app.MinAreaLabel.Text = sprintf('Min Object Area: %d px', autoMinArea);
    app.RadiusLabel.Text  = sprintf('Closing Radius: %d px', autoRadius);

    % --- Step 2: Sequential Execution using Auto Parameters ---
    app.DenoisedData = app.runDenoisingStage(app.RawImageData, autoDenoiseIter);
    app.BinaryMask   = app.runSegmentationStage(app.DenoisedData, autoSens);
    app.BinaryMask   = app.runMorphologyStage(app.BinaryMask, autoMinArea, autoRadius);

    % --- Step 3: Render ---
    app.renderVisualResults();
    app.ExportButton.Enable = 'on';
    end

    %% Image Format Preparation
function normImg = prepareRawImage(~, rawMatrix)
    if size(rawMatrix, 3) == 3
        rawMatrix = rgb2gray(rawMatrix);
    end

    normImg = im2double(rawMatrix);
    
end
   

