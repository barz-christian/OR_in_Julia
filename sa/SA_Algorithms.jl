
function generate_initial_solution(data::cflp_data, k::Int64)
    """
    returns an initial solution to the CFLP, where the number of open facilities migth exceed k

    open_facilities: if k is big open all facilities else open a random number of facilities
    assignment: customer demand to facility is done heuristically by assign customer's 
        demand the open facility with maximal available capacity

    N.B.
        1. initial solution my have more open facilities than k
    """
    if k > data.m / 2 
        initial_facilities = [true for _ in 1:data.m]
    else
        initial_facilities = rand(Bool, data.m)
        while sum(data.demand) > sum([data.capacity[j] * initial_facilities[j] for j in 1:data.m])
            initial_facilities = rand(Bool, data.m)
        end
    end
    
    assignment = zeros(Int, data.m, data.n)

    demand = copy(data.demand)
    capacities = [initial_facilities[j] * data.capacity[j] for j in 1:data.m]

    # assign customer's demand the open facility with maximal available capacity
    for i in 1:data.n
        while demand[i] > 0
            j = findmax(capacities)[2]
            if demand[i] <= capacities[j]
                assignment[j,i] = demand[i]
                capacities[j] -= demand[i]
                demand[i] = 0
            elseif demand[i] > capacities[j]
                assignment[j,i] = capacities[j]
                demand[i] -= capacities[j]
                capacities[j] = 0
            else
                println("error in initial assigment generation check generate_initial_solution")
            end
        end
    end
    return cflp_solution(data, initial_facilities, assignment)
end


function heuristic_client_facility_assignment(
        data::cflp_data, open_facilities::Vector{Bool})
    """
    returns m times n matrix with elements representing the demand of customer i served by facility j
    assignment is done by assigning the clients demand to the cheapest open facilitiy, more precisely:

    for i in customer
        while dem[i] > 0
            find j in facility with facility_cap[j] > 0 and cost_var[i,j] is minimal
        if dem[i] <= facility_cap[j]
            assignm[j,i] = dem[i]
            facility_cap[j] = facility_cap[j] - dem[i]
            dem[i] = 0
        if dem[i] > facility_cap[j]
            assgnm[j,i] = facility_cap[j]
            dem[i] = dem[i] - facility_cap[j]
            facility_cap[j] = 0
        return assignment    
    """

    # create assignment matrix
    assignment = zeros(Int, data.m, data.n)

    # get available facility capacities
    facility_cap = [data.capacity[i] * open_facilities[i] for i in 1:data.m] # usually elementwise multiplication in Julia is done by .*, but here we get a 3x3 matrix instead of a vector
    customer_demand = copy(data.demand)
    # initialize available facilities, because we want to use findmin later assign a big number to non open facilities
    facilities = [1. for j in 1:data.m]
    facilities[facility_cap .< 1] .= data.bigM_customer
    
    for i in 1:length(customer_demand)
        failsafe = 0
        while customer_demand[i] > 0 
            if failsafe > data.m * data.n
                break
            else 
                failsafe +=  1
            end
            j = findmin([data.cost_var[i,j] * facilities[j] for j in 1:data.m])[2]
            if customer_demand[i] <= facility_cap[j]
                assignment[j,i] += customer_demand[i]
                facility_cap[j] -= customer_demand[i]
                customer_demand[i] = 0
                facilities[facility_cap .< 1] .= data.bigM_customer
            end
            if customer_demand[i] > facility_cap[j]
                assignment[j,i] += facility_cap[j]
                customer_demand[i] -= facility_cap[j]
                facility_cap[j] = 0
                facilities[facility_cap .< 1] .= data.bigM_customer
            end
            
            # if all demand is allocated stop loop
            if sum(customer_demand) == 0
                break
            end
        end
    end
    return assignment
end

function generate_candidate_facility(data::cflp_data, solution::cflp_solution, k::Int)
    """
    returns cflp_solution in which the decision on open facilities is randomly modified
    the allocation of client demand to facilities is done using the heuristic assignment
    """
    # generate new candidate for open facilities by swaping the value at a random index
    candidate = copy(solution.open_facilities)
    idx = rand(1:data.m)
    candidate[idx] = !candidate[idx]
    candidate_solution_heu = cflp_solution(data, candidate, heuristic_client_facility_assignment(data, candidate))
    
    # swap an index if generated candidate is infeasible            
    while !test_cflp_solution(data, candidate_solution_heu, k)
        idx = rand(1:data.m)
        candidate[idx] = !candidate[idx]
        candidate_solution_heu = cflp_solution(data, candidate, heuristic_client_facility_assignment(data, candidate))
    end     

    return candidate_solution_heu
end

function generate_candidate_assignment(data::cflp_data, solution::cflp_solution)
    """
    returns a cflp_solution where the open_facilities are equal to the input, but
    a random part of one assignment of a client demand to facilities is move to a facilitiy 
    with free capacity

    N.B. In the current implementation it is possible, that the assignment matrix does not change
    (this happens when j_free = j_rand, i.e. we take demand from the facilitiy but assign it back again)
    In particular the SA is not exploring the search space, as its stays at the solution until the descision on open facilities changes
    
    In particular this happens when J = {j_rand}
    In particular this happend with random data when k has to be choosen close to number of facilities to fulfill feasibility

    In the next iteration we could implement a another decision, for example
    "that we simply swap a suitable demand between clients under the assumption that both have different facilities" 
    """
    
    assignment = copy(solution.assignment)
    
    # determine free capacity as difference of available capacity minus assigned capacity
    free_capacity = [data.capacity[j] * solution.open_facilities[j] for j in 1:data.m]
    free_capacity -= [sum(solution.assignment[j,:]) for j in 1:data.m]
    
    # get random facility with free capacity
    j_free = rand([j for j in 1:data.m if free_capacity[j]!=0])
    
    # move assigned capacity randomly to j_free
    ## but therefore we need a client and a facility and a random capacity to move first
    i_rand = rand([i for i in 1:data.n])
    J = [j for j in 1:data.m if solution.assignment[j, i_rand] != 0]
    j_rand = rand(J) 

    cap_move = rand(1:min(free_capacity[j_free], solution.assignment[j_rand,i_rand]))
    
    # move capacity
    assignment[j_free,i_rand] += cap_move
    assignment[j_rand,i_rand] -= cap_move
    
    return cflp_solution(data, solution.open_facilities, assignment)
end

function SA_client_facility_assignment(data::cflp_data, solution::cflp_solution,
        start_temp::Float64 = 10.0, end_temp::Float64 = 1.0, alpha::Float64 = 0.5, max_iter::Int64 = 5)
    """
    performs an simulated annealing to find an assignment of client demand to open facilities

    returns cflp_solution with local minimal costs
    """
    
    # initial solution
    current_solution = solution
    best_solution = cflp_solution(data, solution.open_facilities, solution.assignment)

    # iterate
    temp = start_temp

    while temp > end_temp
        for _ in 1:max_iter
            # generate new candidate assigning client demand to open facilities
            candidate_solution = generate_candidate_assignment(data, current_solution)  

            if  candidate_solution.cost < best_solution.cost 
                best_solution = cflp_solution(data, candidate_solution.open_facilities, candidate_solution.assignment)
            end

            if candidate_solution.cost < current_solution.cost
                current_solution = candidate_solution
            else
                acceptance_prob = exp( (current_solution.cost - candidate_solution.cost) / temp )
                if rand() < acceptance_prob
                    current_solution = candidate_solution
                end
            end          
        end        
        temp *= alpha
    end
    
    return  best_solution
    
end

function SA_cflp(
        data::cflp_data, k::Int64, start_temp::Float64 = 10.0, end_temp::Float64 = 1.0, alpha::Float64 = 0.5, max_iter::Int64 = 100)
    """
    TBA
    """
    # generate initial solution 
    current_solution = generate_initial_solution(data, k)
    best_solution = current_solution

    # iterate
    temp = start_temp

    while temp > end_temp
        for _ in 1:max_iter
            # generate a new decision on open facilities
            candidate_solution_heu = generate_candidate_facility(data, current_solution, k)
            
            # run simulated annealing on the assignment
            candidate_solution = SA_client_facility_assignment(data, candidate_solution_heu)

            if  test_cflp_solution(data, candidate_solution, k) && candidate_solution.cost < best_solution.cost 
                best_solution = candidate_solution
            end

            if candidate_solution.cost < current_solution.cost
                current_solution = candidate_solution
            else
                acceptance_prob = exp( (current_solution.cost - candidate_solution.cost) / temp )
                if rand() < acceptance_prob
                    current_solution = candidate_solution
                end
            end
        end
        temp *= alpha
    end

    if !test_cflp_solution(data, best_solution,k)
        println("did not found a feasible solution")
    end
    
    return  best_solution
end