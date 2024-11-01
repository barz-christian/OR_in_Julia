"""
In/Output-functions
"""

using Printf


function gen_data(
        facility_number::Integer = 10,
        client_number::Integer = 15,
        cost_bound_fix::Real = 1000,
        cost_bound_var::Real = 100,
        demand_bound::Integer = 30,
        capacity_bound::Integer = 1000
    )
    """
    returns randomly generates demand and costs for a capacitated facility location problem
    params:
    - ...
    """

    # client demand
    l = floor(Int, demand_bound/10)
    d = rand(l:demand_bound, client_number)
    
    # capacities
    l = floor(Int, capacity_bound/10)
    q = rand(l:capacity_bound, facility_number)
    
    # variable costs
    c_v = round.(rand(client_number, facility_number) * cost_bound_var, digits = 2)

    # fixed costs 
    c_f = round.(rand(facility_number)* cost_bound_fix, digits = 2)
    
    # exclude infeaseble data, i.e. if demand > capacities than regenerate both data
    failsafe = 0
    while sum(d) > sum(q) 
        failsafe += 1
        if failsafe > 100
            break
        end
        # client demand
        l = floor(Int, demand_bound/10)
        d = rand(l:demand_bound, client_number)
        l = floor(Int, capacity_bound/10)
        q = rand(l:capacity_bound, facility_number)
    end
    
    return cflp_data(c_f, c_v, q, d)
    
end

 


function print_solution(solution::cflp_solution, head::Bool=false)
    """
    simple print function to print solution in a more human readable form
    if head is true we just print 5 client to facility assignment
    """
    
    println("Total cost are:", solution.cost)
    println("Open facilities:", [i for i in 1:length(solution.open_facilities) if solution.open_facilities[i] > 0])
    println("Assignment:")
    sol = round.(solution.assignment, digits=0)
    
    for i in 1:size(sol)[2]
        if head
            if i > 5
                break
            end
        end
        for j in 1:size(sol)[1]  
            if abs(sol[j,i]) > 0.
                s = @sprintf "customer %3d gets %15f from facility %3d" i round(sol[j,i], digits=1) j
                println(s)
            end
        end
    end    
end