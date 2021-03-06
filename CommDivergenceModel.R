#install.packages("MCMCpack")
#install.packages("ecodist")
#install.packages("VGAM")
library(MCMCpack) 
library(ecodist)
library(VGAM)

#setting seed to ensure consistency
set.seed(14567)
options(scipen = 99)

#NOTES
#we need to come up with a better sparsity preserving generation distribution
#need to deal with averaging effect somehow

#--------------------------------#
#-----BIG BLOCK OF FUNCTIONS-----#
#--------------------------------#


#function to generate communities. Parameters are:
# indiv =  number of individuals in each community, 
# m = number of microbe taxa in each individual
#numcom = the number of communities in total
#abund_microbe =the maximum abundance of a microbe

generateDiff = function(indiv, m, numcom, abund_microbe){
  x = list()
  y = list()
  for(j in 1:numcom){
		for(i in 1:indiv){
			# generate random values for microbial abundance using a uniform prob. distribution
		 y[[i]] = round(runif(m, 0, abund_microbe)) 
		  
		  # tried with a Zero-inflated Poisson to generate sparse data more like real life
		  # this isn't quite right, because the max values are too low
		  # I am not sure what the best distribution is to use here, we will have to figure that out.
		  # I thought about using a "Dirichlet process" algorithm here....
		  # I think we will need to think about how best to do this and perhaps consult the literature
		  # to see what sorts of distributions people have used to model microbial data
		  
		  #y[[i]] = rzipois(m, lambda = 1, pstr0 = .5)*abund_microbe
		  
		  y[[i]] = 	   round(rdirichlet(1, rzipois(m, lambda = 1, pstr0 = .5))*(abund_microbe))
		}
		 x[[j]] = y
  }
	return(x)
}

#generate with identical values for all individuals in all communities

generateSame = function(indiv, m, numcom, abund_microbe){
  x = list()
  y = list()
  
  hostzero = round(rdirichlet(1, rzipois(m, lambda = 1, pstr0 = .5))*(abund_microbe))
  for(j in 1:numcom){
		for(i in 1:indiv){
			y[[i]] = hostzero
		}
		 x[[j]] = y

  }
	return(x)
}




#function to do dirichlet/other replacement of individuals with new microbes
#Parameters are: 
#community = a list representing a community that we are replacing individuals inside

community = sandbox
replacement = function(community){  	
  	
  		#choose a community to replace
  		replaced_comm=round(runif(1, 1, length(community)))
  	
  		#choose an individual at random to replace
	  replaced=round(runif(1, 1,individuals))
	  
	  #here replace this indiv. in this comm. with zero. Note the repetition. I think this was
	  #messing things up
	  community[[replaced_comm]][[replaced]] = rep(0,length(community[[replaced_comm]][[replaced]]))			
	  	  
	  #summing function (calculate sum of each microbe and then divide by number of non-zero individuals in population)
	  #then turn that into a percentage 
	  dirichletVector = Reduce("+",community[[replaced_comm]])/(abund_microbe*individuals)
    
	  #note that because our individual probabilities are so low, these all get rounded to zero
	  #If we used way bigger values for abund_microbe, like 100000, then the number start to look better and we preserve sparsity
	  #however, we still don't get any real runaway effects, where the overall rank abundance distribution is super skewed
	  #I think we may have to use much larger numbers for this function to work right
	  community[[replaced_comm]][[replaced]] = round(rdirichlet(1, dirichletVector)*(abund_microbe))

#TEST
#community[[replaced_comm]][[replaced]] = round(rdirichlet(1, rzipois(m, lambda = 1, pstr0 = .5))*(abund_microbe))
	 
	  # print(replaced_comm)
	  # print(replaced)
	 
	  return(community)
}
#replacement(sandbox)


#input are list elements each of a list
divergence = function(comm1, comm2, method2){
	
	#compute distance metric between two communities
	#first we compress each community into one datum via summing, then we bind them together into 
	#a dataframe to facilitate the use of the distance function
	
	out = distance(rbind(colSums(t(as.data.frame(comm1))), colSums(t(as.data.frame(comm2)))), method=method2)
	return(out)
}


model = function(sandbox){
  require("MCMCpack")
  #clearing output list(holds mean divergence)
  divOut = NULL
  for (z in plotpoints){
  	
  	k=1
    repeat{
    	print(k)
    	sandbox = replacement(sandbox) 
    	k=k+1
    	if( (k >= z)){
    		break
    		}
    	}
    	
    div=NA
    k=1
    for(i in 1:length(sandbox)){
        for(j in 1:length(sandbox)){
          if(i != j){
            div[k] = divergence(sandbox[[i]],sandbox[[j]], "bray")
            k=k+1
          }else{next}
        }
     }
      #outputs average divergence in ascending order
      divOut[length(divOut)+1] = mean(div)
    }
  return(list(divOut, sandbox))
}




#----------------------------------#
#-----VERY IMPORTANT VARIABLES-----#
#----------------------------------#

communities = 10
individuals = 10
microbes = 100
abund_microbe = 1000	


#points at which we calculate the divergence
plotpoints = seq(from = 10, to = 100, by=20)

#---------------------------------------#
#-----GENERATING INITIAL CONDITIONS-----#
#---------------------------------------#

sandbox = generateSame(individuals, microbes, communities, abund_microbe)
#sandbox = generateDiff(individuals, microbes, communities, abund_microbe)

#save original communities
sandbox_original = sandbox

#save communities post running model
out = model(sandbox)

#plot divergence versus time
plot(plotpoints, out[[1]], ylab="Divergence", xlab = "Time step")

# #compare two communities pre and post run, they changed markedly
 # sandbox_original[[10]][[10]]
 # out[[2]][[10]][[10]]



