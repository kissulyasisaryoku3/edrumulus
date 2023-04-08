
% testing clipping compensation

% TEST
%d=0.13;x=[0.0, 0.05, 0.08, 0.1, 0.15, 0.2, 0.4, 0.6, 0.8, 0.9, 1.0, 1.1, 1.2];subplot(311),plot(1-(0:d:1).^2,'.-');subplot(312),plot((0:d:1).^2,'.-');subplot(313),plot(x);axis([1, 8, 0, 1])

pkg load signal
close all;

use_pd120 = true;
%use_pd120 = false;

if use_pd120
  test_files = {"../../algorithm/signals/pd120_single_hits.wav", {9917:9931, 14974:14985, 22525:22538, 35014:35025}};
  amplification_mapping = 10 .^ ([0:0.09:10] .^ 2);
else
  test_files = {"../../algorithm/signals/pd8.wav", {67140:67146, 70170:70175, 73359:73363, 246312:246317, 252036:252039, 296753:296757}};
  amplification_mapping = 10 .^ ([0:0.56:5] .^ 2);
end

clip_limit                 = 1900; % approx. for 12 bit ADC
clip_factor_range          = 1 ./ (1:-0.04:0.04);
num_clipped_val            = [];
amplification_compensation = [];
cnt                        = 1;

for i = 1:size(test_files, 1)

  % load test data
  x = audioread(test_files{i, 1});

  for j = 1:length(test_files{i, 2})

    % pick one peak and normalize
    x_org = x(test_files{i, 2}{j}, 1);
    x_org = x_org / max(x_org); % normalize original input signal

%figure; plot(x_org, '.-'); grid on;

    for idx = 1:length(clip_factor_range)

      % clip
      x_org_scaled  = x_org * clip_limit * clip_factor_range(idx);
      x_org_clipped = max(-clip_limit, min(clip_limit, x_org_scaled));

%figure; plot(x_org_clipped, '.-'); grid on; ax = axis; hold on; plot([ax(1), ax(2)], [clip_limit, clip_limit], 'r')

      % count clipped values
      clip_indexes                         = find(abs(x_org_clipped - clip_limit) < 5 / 2 ^ 12);
      num_clipped_val(idx, cnt)            = length(clip_indexes);
      amplification_compensation(idx, cnt) = amplification_mapping(1 + num_clipped_val(idx, cnt));

      % use distance of mean left/right neighbor samples to clipping limit as additional offset
      correction_offset_applied = false;

      if num_clipped_val(idx, cnt) > 0

        left_index  = min(clip_indexes) - 1;
        right_index = max(clip_indexes) + 1;

        if (left_index > 0) && (right_index <= length(x_org_scaled))

          % note: use linear domain for offset calculation
          neighbor = mean([x_org_scaled(left_index), x_org_scaled(right_index)]);

          % x: point just below the limit (neighbor)
          % a: x / x_max, where x_may is the maximum of the peak
          % l: clip limit (for ESP32 usually ~1800)
          % y = x_max / l
          % a = x_max / x
          % -> y = a * x / l
          amplification_compensation(idx, cnt) = amplification_mapping(1 + num_clipped_val(idx, cnt)) * neighbor / clip_limit;
          correction_offset_applied            = true;

% TEST
%amplification_compensation(idx, cnt) = min(amplification_compensation(idx, cnt), amplification_mapping(1 + num_clipped_val(idx, cnt) - 1));

% TEST
%amplification_compensation(idx, cnt) = max(amplification_compensation(idx, cnt), amplification_mapping(1 + num_clipped_val(idx, cnt) - 1));

%amplification_compensation(idx, cnt) = amplification_mapping(1 + num_clipped_val(idx, cnt));

        end

      end

      if ~correction_offset_applied

        % if no neighbors are available, use worst case assumption of last attenuation
        amplification_compensation(idx, cnt) = amplification_mapping(1 + num_clipped_val(idx, cnt) - 1);

      end

    end

    cnt = cnt + 1;

%figure; plot(num_clipped_val(:, i), 20 * log10(clip_factor_range)); grid on;

  end

end

% results plot
figure; plot(20 * log10(clip_factor_range), 20 * log10(amplification_compensation), '.-'); grid on;
hold on; plot(20 * log10(clip_factor_range), 20 * log10(clip_factor_range), '--k');
axis(20 * log10([min(clip_factor_range), max(clip_factor_range), min(clip_factor_range), max(clip_factor_range)]));
xlabel('actual clipping'); ylabel('estimated clipping amplification');


