% ==========================================================================
% RDH_2DHIST_BP.m
% Reversible Data Hiding With Brightness Preserving CE by 2D Histogram
%
% Paper: Wu H-T., Cao X., Jia R., Cheung Y-M.
%        IEEE Trans. Circuits Syst. Video Technol., 32(11), 7605-7617, 2022
%        DOI: 10.1109/TCSVT.2022.3180007
%
% Algorithm (Sec. III):
%  A. 2D histogram of non-overlapping pixel pairs (Sec. II-A)
%  B. 4-direction modification: LHS/RHS (columns) + DHS/UHS (rows) Eq.(3-7)
%  C. Brightness preservation: pendular direction choice (Sec. III-B)
%  D. Side info: 17 bits/iter + location map (Sec. III-C)
%  E. Stopping: pure capacity > 34 bits (Sec. III-D)
%  F. Extraction & recovery: Eq.(8-13) (Sec. III-E)
%  Color images: process R, G, B independently.
%
% Run: RDH_2DHIST_BP
% ==========================================================================
function RDH_2DHIST_BP()
    clc; close all;
    fprintf('=== RDH-2DHIST-BP: 2D Histogram CE with Brightness Preservation ===\n');
    fprintf('    Wu, Cao, Jia, Cheung — IEEE TCSVT 32(11), 7605-7617, 2022\n\n');

    imgs  = generate_test_images();
    names = {'USC_Lena','USC_Baboon','Kodak01','Kodak02','McMaster01','McMaster02'};
    N_ITER = 80;

    fprintf('--- Exp 1: Metrics (n=%d) ---\n', N_ITER);
    fprintf('%-14s %7s %7s %7s %7s %7s\n','Image','RCE','PSNR','SSIM','BD','bpp');
    fprintf('%s\n', repmat('-',1,55));
    for k = 1:numel(names)
        rng(42); pay = randi([0 1],1,50000,'uint8');
        [I_emb, meta] = rdh_2dhist_embed(imgs{k}, pay, N_ITER);
        rce  = compute_rce(imgs{k}, I_emb);
        pv   = compute_psnr(imgs{k}, I_emb);
        sv   = compute_ssim_approx(imgs{k}, I_emb);
        bd   = compute_bd(imgs{k}, I_emb);
        bpp  = meta.total_emb / (size(imgs{k},1)*size(imgs{k},2));
        fprintf('%-14s %7.4f %7.2f %7.4f %7.4f %7.4f\n', names{k},rce,pv,sv,bd,bpp);
    end

    fprintf('\n--- Exp 2: Reversibility (20000 bits) ---\n');
    for k = 1:numel(names)
        rng(42); pay = randi([0 1],1,20000,'uint8');
        [I_emb, meta] = rdh_2dhist_embed(imgs{k}, pay, N_ITER);
        [I_rec, D_ext] = rdh_2dhist_extract(I_emb, meta);
        ok   = isequal(imgs{k}, I_rec);
        n_c  = min(numel(D_ext), numel(pay));
        errs = sum(D_ext(1:n_c) ~= pay(1:n_c));
        fprintf('  %-14s → Reversible: %s | Bit errors: %d\n', names{k}, string(ok), errs);
    end

    fprintf('\n--- Exp 3: bpp vs n ---\n');
    n_vals = [20 40 60 80];
    fprintf('%-14s',  'Image');
    for nv = n_vals, fprintf('%8s', sprintf('n=%d',nv)); end; fprintf('\n%s\n',repmat('-',1,46));
    for k = 1:numel(names)
        fprintf('%-14s', names{k});
        npix = size(imgs{k},1)*size(imgs{k},2);
        for nv = n_vals
            rng(42); pay = randi([0 1],1,100000,'uint8');
            [~, meta] = rdh_2dhist_embed(imgs{k}, pay, nv);
            fprintf('%8.4f', meta.total_emb/npix);
        end
        fprintf('\n');
    end
    fprintf('\nDone.\n');
end

% ==========================================================================
%  MAIN EMBED: color image → process R,G,B independently
% ==========================================================================
function [I_emb, meta] = rdh_2dhist_embed(I, payload, n_iter)
    I_emb = I;
    meta  = struct();
    ch_names = {'R','G','B'};
    total_emb = 0;
    pay_ptr = 1;
    for c = 1:3
        ch = double(I(:,:,c));
        cap_est = estimate_cap(ch, n_iter);
        n_bits  = min(cap_est, numel(payload) - pay_ptr + 1);
        if n_bits < 1, n_bits = 1; end
        pay_c   = payload(pay_ptr : min(pay_ptr+n_bits-1, end));
        [ch_emb, mc] = embed_channel(ch, pay_c, n_iter);
        I_emb(:,:,c) = uint8(ch_emb);
        meta.(ch_names{c}) = mc;
        total_emb = total_emb + mc.n_emb;
        pay_ptr   = pay_ptr + mc.n_emb;
    end
    meta.total_emb = total_emb;
    meta.size      = size(I);
end

% ==========================================================================
%  EMBED ONE CHANNEL
% ==========================================================================
function [img_out, mc] = embed_channel(img, payload, n_iter)
    [rows, cols] = size(img);
    flat  = img(:);
    N     = numel(flat);
    Np    = floor(N/2)*2;   % ensure even
    orig_brightL = mean(flat(1:2:Np));
    orig_brightR = mean(flat(2:2:Np));

    chain   = struct('p',[],'r',[],'q',[],'s',[],'mode',[],'loc_maps',{{}});
    pay_ptr = 1;   n_emb = 0;

    for iter = 1:n_iter
        pairs = [flat(1:2:Np), flat(2:2:Np)];   % [Np/2, 2]
        H     = accumarray([pairs(:,1)+1, pairs(:,2)+1],1,[256,256],@sum,0);
        col_t = sum(H,1);   % 1x256 column totals
        row_t = sum(H,2)';  % 1x256 row totals
        curr_bL = mean(pairs(:,1));
        curr_bR = mean(pairs(:,2));

        % Brightness-guided direction (Sec. III-B)
        if curr_bL > orig_brightL, mode_h = 'LHS'; else, mode_h = 'RHS'; end
        if curr_bR > orig_brightR, mode_v = 'DHS'; else, mode_v = 'UHS'; end

        [ph,rh,cap_h] = find_col_params(H, col_t, mode_h);
        [qv,sv,cap_v] = find_row_params(H, row_t, mode_v);

        if cap_h == 0 && cap_v == 0, break; end

        % Stopping: pure cap > 34 (Sec. III-D)
        if iter == 1 && max(cap_h, cap_v) <= 34, break; end

        if cap_h >= cap_v
            mode = mode_h; p_=ph; r_=rh; q_=-1; s_=-1;
            [flat, loc] = apply_horiz(flat, Np, p_, r_, mode, payload(pay_ptr:end));
        else
            mode = mode_v; p_=-1; r_=-1; q_=qv; s_=sv;
            [flat, loc] = apply_vert(flat, Np, q_, s_, mode, payload(pay_ptr:end));
        end

        n_it = numel(loc.emb_bits);
        chain.p(end+1)=p_; chain.r(end+1)=r_;
        chain.q(end+1)=q_; chain.s(end+1)=s_;
        chain.mode{end+1}=mode;
        chain.loc_maps{end+1}=loc;
        pay_ptr = pay_ptr + n_it;
        n_emb   = n_emb   + n_it;
        if pay_ptr > numel(payload), break; end
    end

    img_out = reshape(flat, rows, cols);
    mc = struct('chain',chain,'n_emb',n_emb,'rows',rows,'cols',cols,'Np',Np);
end

% --------------------------------------------------------------------------
function [p, r, cap] = find_col_params(H, col_t, mode)
    % Find p = max-count column, r = min-count column for LHS/RHS
    if strcmp(mode,'LHS')
        valid_p = 2:255;   % p > 1
    else
        valid_p = 1:254;   % p < 254 (0-indexed: p < 254)
    end
    [~,pi] = max(col_t(valid_p+1));
    p = valid_p(pi);
    if strcmp(mode,'LHS')
        rng_r = 0:p-1;
    else
        rng_r = p+1:255;
    end
    valid_r = rng_r(col_t(rng_r+1) == 0);
    if isempty(valid_r)
        [~,ri] = min(col_t(rng_r+1)+1e9*(col_t(rng_r+1)==0));
        if isempty(rng_r), p=0;r=0;cap=0; return; end
        r = rng_r(ri);
    else
        r = valid_r(1);
    end
    cap = col_t(p+1);
end

function [q, s, cap] = find_row_params(H, row_t, mode)
    if strcmp(mode,'DHS')
        valid_q = 2:255;
    else
        valid_q = 1:254;
    end
    [~,qi] = max(row_t(valid_q+1));
    q = valid_q(qi);
    if strcmp(mode,'DHS')
        rng_s = 0:q-1;
    else
        rng_s = q+1:255;
    end
    valid_s = rng_s(row_t(rng_s+1)==0);
    if isempty(valid_s)
        if isempty(rng_s), q=0;s=0;cap=0; return; end
        [~,si] = min(row_t(rng_s+1));
        s = rng_s(si);
    else
        s = valid_s(1);
    end
    cap = row_t(q+1);
end

% --------------------------------------------------------------------------
function [flat_out, loc] = apply_horiz(flat, Np, p, r, mode, payload)
% Apply LHS (Eq.3) or RHS (Eq.4) to left pixels of pairs
    left  = flat(1:2:Np);
    right = flat(2:2:Np);
    emb_bits = [];
    loc_map  = [];

    if strcmp(mode,'LHS')
        % Location map: mark left pixels at r or r+1 (Sec. III-C)
        for k = 1:numel(left)
            if left(k)==r,   loc_map(end+1)=0;
            elseif left(k)==r+1, loc_map(end+1)=1; end
        end
        % Merge r→r+1
        left(left==r) = r+1;
        % Shift r+1 < i < p → i-1, embed at p
        bit_ptr = 1;
        for k = 1:numel(left)
            i = left(k);
            if i > r && i < p
                left(k) = i - 1;
            elseif i == p
                be = 0;
                if bit_ptr <= numel(payload), be=payload(bit_ptr); bit_ptr=bit_ptr+1; end
                left(k) = p - be;
                emb_bits(end+1) = be;
            end
        end
    else % RHS: Eq.(4)
        for k = 1:numel(left)
            if left(k)==r,   loc_map(end+1)=0;
            elseif left(k)==r-1, loc_map(end+1)=1; end
        end
        left(left==r) = r-1;
        bit_ptr = 1;
        for k = 1:numel(left)
            i = left(k);
            if i > p && i < r
                left(k) = i + 1;
            elseif i == p
                be = 0;
                if bit_ptr <= numel(payload), be=payload(bit_ptr); bit_ptr=bit_ptr+1; end
                left(k) = p + be;
                emb_bits(end+1) = be;
            end
        end
    end

    flat_out = flat;
    flat_out(1:2:Np) = left;
    loc = struct('emb_bits', emb_bits, 'loc_map', loc_map);
end

function [flat_out, loc] = apply_vert(flat, Np, q, s, mode, payload)
% Apply DHS (Eq.6) or UHS (Eq.7) to right pixels of pairs
    right    = flat(2:2:Np);
    emb_bits = [];
    loc_map  = [];

    if strcmp(mode,'DHS')
        for k = 1:numel(right)
            if right(k)==s,   loc_map(end+1)=0;
            elseif right(k)==s+1, loc_map(end+1)=1; end
        end
        right(right==s) = s+1;
        bit_ptr = 1;
        for k = 1:numel(right)
            j = right(k);
            if j > s && j < q
                right(k) = j - 1;
            elseif j == q
                be = 0;
                if bit_ptr <= numel(payload), be=payload(bit_ptr); bit_ptr=bit_ptr+1; end
                right(k) = q - be;
                emb_bits(end+1) = be;
            end
        end
    else % UHS: Eq.(7)
        for k = 1:numel(right)
            if right(k)==s,   loc_map(end+1)=0;
            elseif right(k)==s-1, loc_map(end+1)=1; end
        end
        right(right==s) = s-1;
        bit_ptr = 1;
        for k = 1:numel(right)
            j = right(k);
            if j > q && j < s
                right(k) = j + 1;
            elseif j == q
                be = 0;
                if bit_ptr <= numel(payload), be=payload(bit_ptr); bit_ptr=bit_ptr+1; end
                right(k) = q + be;
                emb_bits(end+1) = be;
            end
        end
    end

    flat_out = flat;
    flat_out(2:2:Np) = right;
    loc = struct('emb_bits', emb_bits, 'loc_map', loc_map);
end

% ==========================================================================
%  EXTRACT + RECOVER
% ==========================================================================
function [I_rec, D_ext] = rdh_2dhist_extract(I_emb, meta)
    I_rec = I_emb;
    D_ext = [];
    ch_names = {'R','G','B'};
    for c = 1:3
        ch = double(I_emb(:,:,c));
        [ch_rec, d_c] = extract_channel(ch, meta.(ch_names{c}));
        I_rec(:,:,c) = uint8(ch_rec);
        D_ext = [D_ext, d_c]; %#ok<AGROW>
    end
end

function [img_out, D_ext] = extract_channel(img, mc)
    flat = img(:);
    Np   = mc.Np;
    chain = mc.chain;
    n_iter = numel(chain.mode);
    D_ext = [];

    for iter = n_iter:-1:1
        mode  = chain.mode{iter};
        p_    = chain.p(iter);
        r_    = chain.r(iter);
        q_    = chain.q(iter);
        s_    = chain.s(iter);
        loc   = chain.loc_maps{iter};

        if ismember(mode, {'LHS','RHS'})
            [flat, bits] = reverse_horiz(flat, Np, p_, r_, mode, loc);
        else
            [flat, bits] = reverse_vert(flat, Np, q_, s_, mode, loc);
        end
        D_ext = [bits, D_ext]; %#ok<AGROW>
    end
    img_out = reshape(flat, mc.rows, mc.cols);
end

function [flat_out, bits] = reverse_horiz(flat, Np, p, r, mode, loc)
    left = flat(1:2:Np);
    bits = [];

    if strcmp(mode,'LHS')
        % Extract from p-1 (be=1) or p (be=0) → Eq.(8) dh=1 for LHS
        for k = 1:numel(left)
            if left(k)==p-1,  bits(end+1)=1; left(k)=p;
            elseif left(k)==p, bits(end+1)=0; end
        end
        % Reverse shift: r+1 < i <= p-1 → i+1; restore merged col
        for k = 1:numel(left)
            i = left(k);
            if i > r && i < p
                left(k) = i + 1;
            end
        end
        % Restore location map: pixels at r+1 → original r or r+1
        lm_ptr = numel(loc.loc_map);
        for k = numel(left):-1:1
            if left(k) == r+1 && lm_ptr > 0
                if loc.loc_map(lm_ptr)==0, left(k)=r; end
                lm_ptr = lm_ptr - 1;
            end
        end
    else % RHS: Eq.(8) dh=-1
        for k = 1:numel(left)
            if left(k)==p+1,  bits(end+1)=1; left(k)=p;
            elseif left(k)==p, bits(end+1)=0; end
        end
        for k = 1:numel(left)
            i = left(k);
            if i > p && i < r
                left(k) = i - 1;
            end
        end
        lm_ptr = numel(loc.loc_map);
        for k = numel(left):-1:1
            if left(k) == r-1 && lm_ptr > 0
                if loc.loc_map(lm_ptr)==0, left(k)=r; end
                lm_ptr = lm_ptr - 1;
            end
        end
    end
    flat_out = flat;
    flat_out(1:2:Np) = left;
end

function [flat_out, bits] = reverse_vert(flat, Np, q, s, mode, loc)
    right = flat(2:2:Np);
    bits  = [];

    if strcmp(mode,'DHS')  % Eq.(9) dv=1
        for k = 1:numel(right)
            if right(k)==q-1,  bits(end+1)=1; right(k)=q;
            elseif right(k)==q, bits(end+1)=0; end
        end
        for k = 1:numel(right)
            j = right(k);
            if j > s && j < q, right(k) = j+1; end
        end
        lm_ptr = numel(loc.loc_map);
        for k = numel(right):-1:1
            if right(k)==s+1 && lm_ptr>0
                if loc.loc_map(lm_ptr)==0, right(k)=s; end
                lm_ptr = lm_ptr - 1;
            end
        end
    else % UHS: Eq.(9) dv=-1
        for k = 1:numel(right)
            if right(k)==q+1,  bits(end+1)=1; right(k)=q;
            elseif right(k)==q, bits(end+1)=0; end
        end
        for k = 1:numel(right)
            j = right(k);
            if j > q && j < s, right(k) = j-1; end
        end
        lm_ptr = numel(loc.loc_map);
        for k = numel(right):-1:1
            if right(k)==s-1 && lm_ptr>0
                if loc.loc_map(lm_ptr)==0, right(k)=s; end
                lm_ptr = lm_ptr - 1;
            end
        end
    end
    flat_out = flat;
    flat_out(2:2:Np) = right;
end

% ==========================================================================
%  CAPACITY ESTIMATE
% ==========================================================================
function cap = estimate_cap(ch, n_iter)
    flat = ch(:);
    Np   = floor(numel(flat)/2)*2;
    left = flat(1:2:Np);
    ct   = histcounts(left, 0:256);
    [sv, ~] = sort(ct,'descend');
    cap = sum(sv(1:min(n_iter,numel(sv))));
end

% ==========================================================================
%  METRICS
% ==========================================================================
function rce = compute_rce(I, I_emb)
% RCE [45]: 0.5 = no change, >0.5 = enhanced
    f = @(X) (double(max(X(:)))-double(min(X(:)))) / ...
             (double(max(X(:)))+double(min(X(:)))+1e-10);
    rce_vals = zeros(1,3);
    for c=1:3
        c_orig = f(I(:,:,c)); c_enh = f(I_emb(:,:,c));
        rce_vals(c) = 0.5*(1 + (c_enh-c_orig)/(c_orig+1e-10));
    end
    rce = mean(rce_vals);
end

function p = compute_psnr(I, I_emb)
    mse = mean((double(I(:))-double(I_emb(:))).^2);
    if mse==0, p=Inf; else, p=10*log10(255^2/mse); end
end

function sv = compute_ssim_approx(I, I_emb)
    sv_all = zeros(1,3);
    for c=1:3
        A=double(I(:,:,c)); B=double(I_emb(:,:,c));
        mu1=mean(A(:)); mu2=mean(B(:));
        s1=std(A(:)); s2=std(B(:));
        cov12=mean((A(:)-mu1).*(B(:)-mu2));
        C1=6.5025; C2=58.5225;
        sv_all(c)=(2*mu1*mu2+C1)*(2*cov12+C2)/((mu1^2+mu2^2+C1)*(s1^2+s2^2+C2));
    end
    sv = mean(sv_all);
end

function bd = compute_bd(I, I_emb)
% Brightness difference: |mean(original) - mean(enhanced)|
    bd = abs(mean(double(I(:))) - mean(double(I_emb(:))));
end

% ==========================================================================
%  SYNTHETIC COLOR TEST IMAGE GENERATOR
% ==========================================================================
function [imgs, names] = generate_test_images()
    imgs = cell(6,1); sz = 512;
    % USC-SIPI style
    rng(1); I=zeros(sz,sz,3,'uint8');
    [X,Y]=meshgrid(1:sz,1:sz);
    I(:,:,1)=uint8(min(255,128+round(80*sin(X/30).*cos(Y/30))));
    I(:,:,2)=uint8(min(255,100+round(60*cos(X/20+Y/20))));
    I(:,:,3)=uint8(min(255,90+round(70*sin(X/40))));
    imgs{1}=I;

    rng(2); I=zeros(sz,sz,3,'uint8');
    I(:,:,1)=uint8(min(255,max(0,128+round(80*randn(sz)))));
    I(:,:,2)=uint8(min(255,max(0,110+round(70*randn(sz)))));
    I(:,:,3)=uint8(min(255,max(0,95+round(65*randn(sz)))));
    imgs{2}=I;

    % Kodak style 768x512
    sz2=[512,768];
    rng(3); I=zeros(sz2(1),sz2(2),3,'uint8');
    [X,Y]=meshgrid(1:sz2(2),1:sz2(1));
    I(:,:,1)=uint8(min(255,140+round(60*sin(X/50).*cos(Y/50))));
    I(:,:,2)=uint8(min(255,120+round(50*cos(X/40))));
    I(:,:,3)=uint8(min(255,100+round(70*sin(Y/60))));
    imgs{3}=I;

    rng(4); I=zeros(sz2(1),sz2(2),3,'uint8');
    I(:,:,1)=uint8(min(255,max(0,150+round(50*randn(sz2)))));
    I(:,:,2)=uint8(min(255,max(0,130+round(40*randn(sz2)))));
    I(:,:,3)=uint8(min(255,max(0,110+round(55*randn(sz2)))));
    imgs{4}=I;

    % McMaster style 500x500 (contrast-reduced by alpha=0.7, Eq.14)
    sz3=500;
    rng(5); I_raw=zeros(sz3,sz3,3,'uint8');
    [X,Y]=meshgrid(1:sz3,1:sz3);
    I_raw(:,:,1)=uint8(min(255,160+round(70*sin(X/35).*cos(Y/35))));
    I_raw(:,:,2)=uint8(min(255,140+round(55*cos(X/25+Y/25))));
    I_raw(:,:,3)=uint8(min(255,120+round(65*sin(X/45))));
    alpha=0.7; Iavg=mean(double(I_raw(:)));
    I_red=uint8(max(0,min(255,round(Iavg+alpha*(double(I_raw)-Iavg)))));
    imgs{5}=I_red;

    rng(6); I_raw=zeros(sz3,sz3,3,'uint8');
    I_raw(:,:,1)=uint8(min(255,max(0,155+round(65*randn(sz3)))));
    I_raw(:,:,2)=uint8(min(255,max(0,135+round(50*randn(sz3)))));
    I_raw(:,:,3)=uint8(min(255,max(0,115+round(60*randn(sz3)))));
    Iavg=mean(double(I_raw(:)));
    imgs{6}=uint8(max(0,min(255,round(Iavg+alpha*(double(I_raw)-Iavg)))));

    names={'USC_Lena','USC_Baboon','Kodak01','Kodak02','McMaster01','McMaster02'};
end
