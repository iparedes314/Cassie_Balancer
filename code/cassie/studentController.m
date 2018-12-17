function tau = studentController(t, s, model, params)
    % Modify this code to calculate the joint torques
    % t - time
    % s - 20x1 state of the robot
    % model - struct containing robot properties
    % params - user defined parameters in studentParams.m
    % tau - 10x1 vector of joint torques

    global control
    % State vector components ID
    q = s(1 : model.n);
    dq = s(model.n+1 : 2*model.n);
    x0 = getInitialState(model);    

    q0 = x0(1:model.n);

%     params = studentParams(model);
%     q0 = params.bestPos;
    
    

    %% Pick control

    switch control
        case 1
            % [Control #1] zero control
            tau = zeros(10,1);

        case 'PD'
            % [Control #2] High Gain Joint PD control on all actuated joints
            kp = 300;
            kd = 70;
            tau = -kp*(q(model.actuated_idx)-q0(model.actuated_idx)) - kd*dq(model.actuated_idx);

        case 'highPD'
            % [Control #3] High Gain Joint PD with individual gains
            % Highest score with these gains is 93.0101
            kp = [1e3;      % abduction
                  1e3;
                  500;      % rotation
                  500;
                  800;      % flexion
                  800;
                  1e5;      % knee
                  1e5;
                  8e2;      % toe
                  8e2];

            kd = [100;      % abduction
                  100;
                  100;      % rotation
                  100;
                  100;      % flexion
                  100;
                  400;      % knee
                  400;
                  200;      % toe
                  200];

            qErr = q(model.actuated_idx)-q0(model.actuated_idx);
            dqErr = dq(model.actuated_idx);
            tau = -kp.*qErr - kd.*dqErr;
            
        case 'force'
            % FORCE control
            
            % Grasp/Contact Map
            % toe order
            [leftFront, leftRear, rightFront, rightRear] = computeFootPositions(q, model);
            
            CoM = q(1:3);
            rleftFront = rHat(leftFront - CoM);
            rleftRear = rHat(leftRear - CoM);
            rrightFront = rHat(rightFront - CoM);
            rrightRear = rHat(rightRear - CoM);
                        
            Gc = [    eye(3),    eye(3),      eye(3),     eye(3);
                  rleftFront, rleftRear, rrightFront, rrightRear];
                
            % Pseudoinverse of grasp map
            pseGc = (Gc')/(Gc*Gc');
            
            % Wrench
            Fga = wrench_genPD(t, q, dq, q0);
            
            % Contact force
            fc = pseGc*Fga;
%             fc = minFC(Gc, pseGc, Fga); 
            
            fc_lf = fc(1:3);
            fc_lb = fc(4:6);
            fc_rf = fc(7:9);
            fc_rb = fc(10:end);
            
            % Jacobian
            [Jlf, Jlb, Jrf, Jrb] = computeFootJacobians(q, dq, model);
            Jlf = Jlf(4:end, 7:16)';
            Jlb = Jlb(4:end, 7:16)';
            Jrf = Jrf(4:end, 7:16)';
            Jrb = Jrb(4:end, 7:16)';
            
            tau_des = Jlf*fc_lf + Jlb*fc_lb + Jrf*fc_rf + Jrb*fc_rb;
            
            tau = -tau_des;

           
        otherwise
            warning('Control not recognized.')
    end



